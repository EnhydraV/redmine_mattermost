# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class MattermostDeliverJobTest < ActiveSupport::TestCase
  include RedmineMattermost::TestHelper

  CHANNEL = { 'team' => 'dev', 'channel' => 'redmine' }.freeze
  PAYLOAD = { 'message' => 'Hello' }.freeze
  ACTOR = { 'username' => 'charlie', 'email' => 'charlie@example.com' }.freeze

  def test_posts_to_the_resolved_channel
    RedmineMattermost::Client.any_instance.expects(:channel_id).with('dev', 'redmine').returns('c1')
    RedmineMattermost::Client.any_instance.expects(:create_post).with({ 'message' => 'Hello', 'channel_id' => 'c1' })

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, PAYLOAD
    end
  end

  def test_does_nothing_when_not_configured
    RedmineMattermost::Client.any_instance.expects(:create_post).never

    with_mattermost_settings 'mattermost_url' => '' do
      MattermostDeliverJob.perform_now CHANNEL, PAYLOAD
    end
  end

  def test_permanent_error_is_logged_and_not_retried
    RedmineMattermost::Client.any_instance.stubs(:channel_id).raises(RedmineMattermost::Client::Error, 'HTTP 404')

    with_mattermost_settings do
      assert_nothing_raised { MattermostDeliverJob.perform_now CHANNEL, PAYLOAD }
    end
    assert_no_enqueued_jobs only: MattermostDeliverJob
  end

  def test_transient_error_is_retried
    RedmineMattermost::Client.any_instance.stubs(:channel_id).raises(RedmineMattermost::Client::TransientError, 'HTTP 503')

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, PAYLOAD
    end
    assert_enqueued_jobs 1, only: MattermostDeliverJob
  end

  def test_actor_goes_through_the_relay_plugin
    RedmineMattermost::Client.any_instance.expects(:relay_post).with(CHANNEL, ACTOR, PAYLOAD).returns({ 'post_id' => 'p1' })
    RedmineMattermost::Client.any_instance.expects(:create_post).never

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, PAYLOAD, ACTOR
    end
  end

  def test_bot_posts_when_the_relay_refuses
    RedmineMattermost::Client.any_instance.stubs(:relay_post).raises(RedmineMattermost::Client::Error, 'HTTP 404')
    RedmineMattermost::Client.any_instance.expects(:channel_id).with('dev', 'redmine').returns('c1')
    RedmineMattermost::Client.any_instance.expects(:create_post).with({ 'message' => 'Hello', 'channel_id' => 'c1' })

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, PAYLOAD, ACTOR
    end
  end

  def test_relay_transient_error_is_retried_without_fallback
    RedmineMattermost::Client.any_instance.stubs(:relay_post).raises(RedmineMattermost::Client::TransientError, 'HTTP 502')
    RedmineMattermost::Client.any_instance.expects(:create_post).never

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, PAYLOAD, ACTOR
    end
    assert_enqueued_jobs 1, only: MattermostDeliverJob
  end
end
