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

  def test_relay_gets_the_actor_message_and_keeps_the_full_one_for_the_bot
    payload = { 'message' => 'Hello by Charlie', 'actor_message' => 'Hello' }
    RedmineMattermost::Client.any_instance.expects(:relay_post)
                             .with(CHANNEL, ACTOR, { 'message' => 'Hello' }, bot_message: 'Hello by Charlie')
                             .returns({ 'post_id' => 'p1' })

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, payload, ACTOR
    end
  end

  def test_bot_fallback_posts_the_full_message
    payload = { 'message' => 'Hello by Charlie', 'actor_message' => 'Hello' }
    RedmineMattermost::Client.any_instance.stubs(:relay_post).raises(RedmineMattermost::Client::Error, 'HTTP 404')
    RedmineMattermost::Client.any_instance.expects(:channel_id).with('dev', 'redmine').returns('c1')
    RedmineMattermost::Client.any_instance.expects(:create_post).with({ 'message' => 'Hello by Charlie', 'channel_id' => 'c1' })

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, payload, ACTOR
    end
  end

  def test_mentions_are_converted_to_mattermost_usernames
    payload = { 'message' => 'To: @oscar@example.com',
                'mention_users' => [{ 'login' => 'oscar@example.com', 'email' => 'oscar@example.com' }] }
    RedmineMattermost::Client.any_instance.expects(:username_for).with('oscar@example.com', 'oscar@example.com').returns('oscar')
    RedmineMattermost::Client.any_instance.expects(:channel_id).with('dev', 'redmine').returns('c1')
    RedmineMattermost::Client.any_instance.expects(:create_post).with({ 'message' => 'To: @oscar', 'channel_id' => 'c1' })

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, payload
    end
  end

  def test_direct_message_target_is_converted_to_the_mattermost_username
    target = { 'username' => 'romeo@example.com', 'email' => 'romeo@example.com' }
    RedmineMattermost::Client.any_instance.expects(:username_for).with('romeo@example.com', 'romeo@example.com').returns('romeo')
    RedmineMattermost::Client.any_instance.expects(:direct_channel_id).with('romeo').returns('d1')
    RedmineMattermost::Client.any_instance.expects(:create_post).with({ 'message' => 'Hello', 'channel_id' => 'd1' })

    with_mattermost_settings do
      MattermostDeliverJob.perform_now target, PAYLOAD
    end
  end

  def test_note_from_a_reply_goes_back_into_its_thread
    payload = { 'message' => 'Hello', 'reply_to' => { 'root_id' => 'root-1', 'channel_id' => 'c1' } }
    RedmineMattermost::Client.any_instance.expects(:channel_id).with('dev', 'redmine').returns('c1')
    RedmineMattermost::Client.any_instance.expects(:create_post).with({ 'message' => 'Hello', 'channel_id' => 'c1', 'root_id' => 'root-1' })

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, payload
    end
  end

  def test_other_channels_get_a_new_post
    payload = { 'message' => 'Hello', 'reply_to' => { 'root_id' => 'root-1', 'channel_id' => 'elsewhere' } }
    RedmineMattermost::Client.any_instance.expects(:channel_id).with('dev', 'redmine').returns('c1')
    RedmineMattermost::Client.any_instance.expects(:create_post).with({ 'message' => 'Hello', 'channel_id' => 'c1' })

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, payload
    end
  end

  def test_relay_receives_the_thread
    reply_to = { 'root_id' => 'root-1', 'channel_id' => 'c1' }
    RedmineMattermost::Client.any_instance.expects(:relay_post)
                             .with(CHANNEL, ACTOR, PAYLOAD, reply_to: reply_to).returns({ 'post_id' => 'p1' })

    with_mattermost_settings do
      MattermostDeliverJob.perform_now CHANNEL, PAYLOAD.merge('reply_to' => reply_to), ACTOR
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
