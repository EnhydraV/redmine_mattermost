package main

import (
	_ "embed"
	"encoding/json"
	"net/http"
	"sync"

	"github.com/mattermost/mattermost/server/public/plugin"
)

//go:embed plugin.json
var manifestJSON []byte

var manifest = mustParseManifest(manifestJSON)

type pluginManifest struct {
	ID      string `json:"id"`
	Version string `json:"version"`
}

func mustParseManifest(data []byte) pluginManifest {
	var m pluginManifest
	if err := json.Unmarshal(data, &m); err != nil {
		panic("invalid plugin.json: " + err.Error())
	}
	return m
}

// Plugin relaie les notifications de Redmine et les publie au nom de l'utilisateur concerné.
type Plugin struct {
	plugin.MattermostPlugin

	configurationLock sync.RWMutex
	configuration     *configuration
}

// ServeHTTP reçoit /plugins/<id>/api/v1/..., préfixe déjà retiré par le serveur.
func (p *Plugin) ServeHTTP(_ *plugin.Context, w http.ResponseWriter, r *http.Request) {
	switch {
	case r.URL.Path == "/api/v1/posts" && r.Method == http.MethodPost:
		p.handleCreatePost(w, r)
	case r.URL.Path == "/api/v1/status" && r.Method == http.MethodGet:
		p.handleStatus(w, r)
	default:
		http.NotFound(w, r)
	}
}
