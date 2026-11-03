package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/mattermost/mattermost/server/public/model"
	"github.com/mattermost/mattermost/server/public/plugin/plugintest"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

var (
	bot      = &model.User{Id: "bot-id", Username: "redmine", IsBot: true}
	charlie  = &model.User{Id: "charlie-id", Username: "charlie", Email: "charlie@example.com"}
	juliette = &model.User{Id: "juliette-id", Username: "juliette"}
	team     = &model.Team{Id: "team-id", Name: "dev"}
	channel  = &model.Channel{Id: "channel-id", TeamId: "team-id", Name: "redmine"}
	notFound = model.NewAppError("test", "not_found", nil, "", http.StatusNotFound)
)

const channelBody = `{
	"target": {"team": "dev", "channel": "redmine"},
	"actor": {"username": "charlie", "email": "charlie@example.com"},
	"post": {"message": "Hello", "props": {"attachments": [{"fallback": "Bug #1", "fields": [{"title": "Status", "value": "New", "short": true}]}]}}
}`

func newTestPlugin(t *testing.T) (*Plugin, *plugintest.API) {
	t.Helper()
	api := &plugintest.API{}
	p := &Plugin{}
	p.SetAPI(api)
	p.setConfiguration(&configuration{AllowedUsernames: "redmine", MatchByEmail: true})
	t.Cleanup(func() { api.AssertExpectations(t) })
	return p, api
}

func serve(p *Plugin, method, path, userID, body string) *httptest.ResponseRecorder {
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	if userID != "" {
		r.Header.Set("Mattermost-User-Id", userID)
	}
	w := httptest.NewRecorder()
	p.ServeHTTP(nil, w, r)
	return w
}

func decodeResponse(t *testing.T, w *httptest.ResponseRecorder) relayResponse {
	t.Helper()
	var response relayResponse
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &response))
	return response
}

func expectChannel(api *plugintest.API) {
	api.On("GetTeamByName", "dev").Return(team, nil)
	api.On("GetChannelByName", "team-id", "redmine", false).Return(channel, nil)
}

func TestUnauthenticatedRequestIsRejected(t *testing.T) {
	p, _ := newTestPlugin(t)

	w := serve(p, http.MethodPost, "/api/v1/posts", "", channelBody)

	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestOtherAccountIsForbidden(t *testing.T) {
	p, api := newTestPlugin(t)
	api.On("GetUser", "charlie-id").Return(charlie, nil)

	w := serve(p, http.MethodPost, "/api/v1/posts", "charlie-id", channelBody)

	assert.Equal(t, http.StatusForbidden, w.Code)
}

func TestInvalidBodyIsRejected(t *testing.T) {
	p, api := newTestPlugin(t)
	api.On("GetUser", "bot-id").Return(bot, nil)

	w := serve(p, http.MethodPost, "/api/v1/posts", "bot-id", `{"target": {"team": "dev"}, "post": {"message": "Hello"}}`)

	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestPostsAsActorWhenActorCanPost(t *testing.T) {
	p, api := newTestPlugin(t)
	api.On("GetUser", "bot-id").Return(bot, nil)
	api.On("GetUserByUsername", "charlie").Return(charlie, nil)
	expectChannel(api)
	api.On("HasPermissionToChannel", "charlie-id", "channel-id", model.PermissionCreatePost).Return(true)
	api.On("CreatePost", mock.MatchedBy(func(post *model.Post) bool {
		attachments := post.Attachments()
		return post.UserId == "charlie-id" &&
			post.ChannelId == "channel-id" &&
			post.Message == "Hello" &&
			len(attachments) == 1 &&
			attachments[0].Fallback == "Bug #1" &&
			len(attachments[0].Fields) == 1 &&
			bool(attachments[0].Fields[0].Short)
	})).Return(&model.Post{Id: "post-id", UserId: "charlie-id"}, nil)

	w := serve(p, http.MethodPost, "/api/v1/posts", "bot-id", channelBody)

	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	assert.Equal(t, relayResponse{PostID: "post-id", UserID: "charlie-id", AsActor: true}, decodeResponse(t, w))
}

func TestFallsBackToBotWhenActorCannotPost(t *testing.T) {
	p, api := newTestPlugin(t)
	api.On("GetUser", "bot-id").Return(bot, nil)
	api.On("GetUserByUsername", "charlie").Return(charlie, nil)
	expectChannel(api)
	api.On("HasPermissionToChannel", "charlie-id", "channel-id", model.PermissionCreatePost).Return(false)
	api.On("HasPermissionToChannel", "bot-id", "channel-id", model.PermissionCreatePost).Return(true)
	api.On("CreatePost", mock.MatchedBy(func(post *model.Post) bool {
		return post.UserId == "bot-id"
	})).Return(&model.Post{Id: "post-id", UserId: "bot-id"}, nil)

	w := serve(p, http.MethodPost, "/api/v1/posts", "bot-id", channelBody)

	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	assert.False(t, decodeResponse(t, w).AsActor)
}

func TestRefusedWhenNobodyCanPost(t *testing.T) {
	p, api := newTestPlugin(t)
	api.On("GetUser", "bot-id").Return(bot, nil)
	api.On("GetUserByUsername", "charlie").Return(charlie, nil)
	expectChannel(api)
	api.On("HasPermissionToChannel", mock.Anything, "channel-id", model.PermissionCreatePost).Return(false)

	w := serve(p, http.MethodPost, "/api/v1/posts", "bot-id", channelBody)

	assert.Equal(t, http.StatusForbidden, w.Code)
	api.AssertNotCalled(t, "CreatePost", mock.Anything)
}

func TestActorIsFoundByEmail(t *testing.T) {
	p, api := newTestPlugin(t)
	api.On("GetUser", "bot-id").Return(bot, nil)
	api.On("GetUserByUsername", "charlie").Return(nil, notFound)
	api.On("GetUserByEmail", "charlie@example.com").Return(charlie, nil)
	expectChannel(api)
	api.On("HasPermissionToChannel", "charlie-id", "channel-id", model.PermissionCreatePost).Return(true)
	api.On("CreatePost", mock.Anything).Return(&model.Post{Id: "post-id", UserId: "charlie-id"}, nil)

	w := serve(p, http.MethodPost, "/api/v1/posts", "bot-id", channelBody)

	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	assert.True(t, decodeResponse(t, w).AsActor)
}

func TestEmailMatchingCanBeDisabled(t *testing.T) {
	p, api := newTestPlugin(t)
	p.setConfiguration(&configuration{AllowedUsernames: "redmine"})
	api.On("GetUser", "bot-id").Return(bot, nil)
	api.On("GetUserByUsername", "charlie").Return(nil, notFound)
	expectChannel(api)
	api.On("HasPermissionToChannel", "bot-id", "channel-id", model.PermissionCreatePost).Return(true)
	api.On("CreatePost", mock.Anything).Return(&model.Post{Id: "post-id", UserId: "bot-id"}, nil)

	w := serve(p, http.MethodPost, "/api/v1/posts", "bot-id", channelBody)

	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	api.AssertNotCalled(t, "GetUserByEmail", mock.Anything)
}

func TestDirectMessageIsSentByActor(t *testing.T) {
	p, api := newTestPlugin(t)
	api.On("GetUser", "bot-id").Return(bot, nil)
	api.On("GetUserByUsername", "charlie").Return(charlie, nil)
	api.On("GetUserByUsername", "juliette").Return(juliette, nil)
	api.On("GetDirectChannel", "charlie-id", "juliette-id").Return(&model.Channel{Id: "dm-id"}, nil)
	api.On("CreatePost", mock.MatchedBy(func(post *model.Post) bool {
		return post.UserId == "charlie-id" && post.ChannelId == "dm-id"
	})).Return(&model.Post{Id: "post-id", UserId: "charlie-id"}, nil)

	body := `{"target": {"username": "Juliette"}, "actor": {"username": "charlie"}, "post": {"message": "Hello"}}`
	w := serve(p, http.MethodPost, "/api/v1/posts", "bot-id", body)

	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
}

func TestStatusReturnsPluginVersion(t *testing.T) {
	p, api := newTestPlugin(t)
	api.On("GetUser", "bot-id").Return(bot, nil)

	w := serve(p, http.MethodGet, "/api/v1/status", "bot-id", "")

	require.Equal(t, http.StatusOK, w.Code)
	assert.JSONEq(t, `{"id": "com.github.enhydrav.redmine-mattermost", "version": "2.0.0"}`, w.Body.String())
}

func TestUnknownRouteIsNotFound(t *testing.T) {
	p, _ := newTestPlugin(t)

	w := serve(p, http.MethodGet, "/api/v1/unknown", "bot-id", "")

	assert.Equal(t, http.StatusNotFound, w.Code)
}

func TestAllowedUsernames(t *testing.T) {
	cfg := &configuration{AllowedUsernames: " redmine, @Redmine-Preprod ,"}

	assert.True(t, cfg.isAllowed("redmine"))
	assert.True(t, cfg.isAllowed("redmine-preprod"))
	assert.False(t, cfg.isAllowed("victor"))
	assert.False(t, (&configuration{}).isAllowed(""))
}
