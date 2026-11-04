# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class MattermostRepliesTest < Redmine::IntegrationTest
  include RedmineMattermost::TestHelper

  fixtures :projects, :users, :email_addresses, :user_preferences, :members, :member_roles, :roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues, :journals,
           :journal_details, :enumerations, :workflows

  SECRET = 's3cret-of-victor'

  def setup
    @previous_secret = ENV.fetch RedmineMattermost::REPLY_SECRET_ENV, nil
    ENV[RedmineMattermost::REPLY_SECRET_ENV] = SECRET
  end

  def teardown
    ENV[RedmineMattermost::REPLY_SECRET_ENV] = @previous_secret
  end

  def test_reply_becomes_a_note_posted_back_in_the_thread
    with_mattermost_settings do
      post_reply username: 'jsmith', message: 'Reply from Charlie'
    end

    assert_response :created
    journal = Issue.find(1).journals.last

    assert_equal 'Reply from Charlie', journal.notes
    assert_equal User.find(2), journal.user
    assert_equal response.parsed_body['journal_id'], journal.id

    payload = mattermost_payloads.last

    assert_equal({ 'root_id' => 'root-1', 'channel_id' => 'chan-1' }, payload['reply_to'])
    assert_equal 1, payload.dig('props', 'redmine_issue_id')
  end

  def test_user_is_found_by_email
    post_reply username: 'juliette', email: 'jsmith@somenet.foo'

    assert_response :created
    assert_equal User.find(2), Issue.find(1).journals.last.user
  end

  def test_unknown_user_is_refused
    post_reply username: 'oscar', email: 'oscar@example.com'

    assert_response :unprocessable_entity
  end

  def test_user_without_note_permission_is_refused
    Role.find(2).remove_permission! :add_issue_notes

    post_reply username: 'dlopper'

    assert_response :forbidden
  end

  def test_empty_message_is_refused
    post_reply username: 'jsmith', message: '  '

    assert_response :unprocessable_entity
  end

  def test_wrong_secret_hides_the_route
    post_reply username: 'jsmith', secret: 'guess'

    assert_response :not_found
    assert_equal 0, Issue.find(1).journals.where(notes: 'Reply from Charlie').count
  end

  def test_route_is_closed_without_configured_secret
    ENV.delete RedmineMattermost::REPLY_SECRET_ENV

    post_reply username: 'jsmith', secret: ''

    assert_response :not_found
  end

  private

  def post_reply(username:, email: nil, message: 'Reply from Charlie', secret: SECRET)
    post '/mattermost/replies',
         params: { issue_id: 1, username: username, email: email, message: message,
                   root_id: 'root-1', channel_id: 'chan-1' }.compact.to_json,
         headers: { 'Content-Type' => 'application/json', MattermostRepliesController::AUTH_HEADER => secret }
  end
end
