# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ClientTest < ActiveSupport::TestCase
  def setup
    @client = RedmineMattermost::Client.new 'https://chat.example.com/', 'bot-token'
  end

  def test_create_post_sends_json_with_bearer_token
    http = mock 'http'
    http.expects(:request).with do |request|
      request.is_a?(Net::HTTP::Post) &&
        request.path == '/api/v4/posts' &&
        request['Authorization'] == 'Bearer bot-token' &&
        request['Content-Type'] == 'application/json' &&
        JSON.parse(request.body) == { 'channel_id' => 'c1', 'message' => 'Hello' }
    end.returns(json_response(Net::HTTPCreated, '201', id: 'p1'))
    stub_http http, host: 'chat.example.com', port: 443, verify_mode: OpenSSL::SSL::VERIFY_PEER

    assert_equal({ 'id' => 'p1' }, @client.create_post('channel_id' => 'c1', 'message' => 'Hello'))
  end

  def test_channel_is_resolved_by_team_and_name
    http = mock 'http'
    http.expects(:request)
        .with { |request| request.path == '/api/v4/teams/name/dev/channels/name/town-square' }
        .returns(json_response(Net::HTTPOK, '200', id: 'c42'))
    stub_http http

    assert_equal 'c42', @client.channel_id_for('team' => 'dev', 'channel' => 'town-square')
  end

  def test_direct_channel_is_created_with_bot_and_user
    http = mock 'http'
    http.expects(:request).with { |request| request.path == '/api/v4/users/username/juliette' }
                          .returns(json_response(Net::HTTPOK, '200', id: 'u-juliette'))
    http.expects(:request).with { |request| request.path == '/api/v4/users/me' }
                          .returns(json_response(Net::HTTPOK, '200', id: 'u-bot'))
    http.expects(:request).with do |request|
      request.path == '/api/v4/channels/direct' && JSON.parse(request.body) == %w[u-bot u-juliette]
    end.returns(json_response(Net::HTTPCreated, '201', id: 'dm1'))
    stub_http http

    assert_equal 'dm1', @client.channel_id_for('username' => 'juliette')
  end

  def test_relay_post_targets_the_server_plugin
    http = mock 'http'
    http.expects(:request).with do |request|
      request.path == '/plugins/com.cubedesigners.redmine/api/v1/posts' &&
        request['Authorization'] == 'Bearer bot-token' &&
        JSON.parse(request.body) == { 'target' => { 'username' => 'juliette' },
                                      'actor' => { 'username' => 'charlie', 'email' => 'charlie@example.com' },
                                      'post' => { 'message' => 'Hello' } }
    end.returns(json_response(Net::HTTPCreated, '201', post_id: 'p1', as_actor: true))
    stub_http http

    response = @client.relay_post({ 'username' => 'juliette' },
                                  { 'username' => 'charlie', 'email' => 'charlie@example.com' },
                                  { 'message' => 'Hello' })

    assert_equal({ 'post_id' => 'p1', 'as_actor' => true }, response)
  end

  def test_client_error_raises_without_leaking_the_token
    http = stub 'http'
    http.stubs(:request).returns(json_response(Net::HTTPNotFound, '404', message: 'Unable to find the channel.'))
    stub_http http

    error = assert_raises(RedmineMattermost::Client::Error) { @client.channel_id 'dev', 'missing' }

    assert_not_kind_of RedmineMattermost::Client::TransientError, error
    assert_includes error.message, 'HTTP 404 Unable to find the channel.'
    assert_not_includes error.message, 'bot-token'
  end

  def test_server_error_is_transient
    http = stub 'http'
    http.stubs(:request).returns(json_response(Net::HTTPServiceUnavailable, '503', message: 'down'))
    stub_http http

    assert_raises(RedmineMattermost::Client::TransientError) { @client.create_post 'message' => 'x' }
  end

  def test_network_error_is_transient
    Net::HTTP.stubs(:start).raises(Errno::ECONNREFUSED)

    assert_raises(RedmineMattermost::Client::TransientError) { @client.create_post 'message' => 'x' }
  end

  def test_ssl_verification_can_be_disabled
    client = RedmineMattermost::Client.new 'https://chat.example.com', 'bot-token', verify_ssl: false
    http = stub 'http'
    http.stubs(:request).returns(json_response(Net::HTTPCreated, '201', id: 'p1'))
    stub_http http, verify_mode: OpenSSL::SSL::VERIFY_NONE

    client.create_post 'message' => 'x'
  end

  private

  def stub_http(http, host: nil, port: nil, verify_mode: nil)
    Net::HTTP.expects(:start).with do |actual_host, actual_port, options|
      (host.nil? || actual_host == host) &&
        (port.nil? || actual_port == port) &&
        (verify_mode.nil? || options[:verify_mode] == verify_mode)
    end.at_least_once.yields(http)
  end

  def json_response(klass, code, body)
    response = klass.new '1.1', code, ''
    response.stubs(:body).returns(body.to_json)
    response
  end
end
