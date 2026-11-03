# frozen_string_literal: true

require 'digest'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module RedmineMattermost
  # Client minimal de l'API REST v4 de Mattermost, authentifié par le jeton du bot
  class Client
    class Error < StandardError; end

    # Erreur réseau, 429 ou 5xx : l'envoi peut être retenté
    class TransientError < Error; end

    API_PATH = '/api/v4'
    RELAY_PATH = "/plugins/#{RedmineMattermost::RELAY_PLUGIN_ID}/api/v1".freeze
    CACHE_TTL = 1.hour
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    NETWORK_ERRORS = [IOError,
                      SocketError,
                      SystemCallError,
                      Timeout::Error,
                      OpenSSL::SSL::SSLError,
                      Net::HTTPBadResponse,
                      Net::ProtocolError].freeze

    def self.from_settings
      return unless RedmineMattermost.configured?

      new RedmineMattermost.server_url,
          RedmineMattermost.bot_token,
          verify_ssl: RedmineMattermost.setting?(:mattermost_verify_ssl)
    end

    def initialize(server_url, token, verify_ssl: true)
      @server_url = server_url.to_s.chomp '/'
      @token = token
      @verify_ssl = verify_ssl
    end

    # target : { 'team' => ..., 'channel' => ... } ou { 'username' => ... }
    def channel_id_for(target)
      if target['username'].present?
        direct_channel_id target['username']
      else
        channel_id target['team'], target['channel']
      end
    end

    def channel_id(team, channel)
      cached "channel/#{team}/#{channel}" do
        request(:get, "/teams/name/#{segment team}/channels/name/#{segment channel}").fetch 'id'
      end
    end

    def direct_channel_id(username)
      cached "direct/#{username}" do
        user = request :get, "/users/username/#{segment username}"
        request(:post, '/channels/direct', [bot_user_id, user.fetch('id')]).fetch 'id'
      end
    end

    def bot_user_id
      cached('me') { request(:get, '/users/me').fetch 'id' }
    end

    def create_post(payload)
      request :post, '/posts', payload
    end

    # Publication par le plugin relais, au nom de l'utilisateur quand il peut publier
    def relay_post(target, actor, payload)
      request :post, '/posts', { 'target' => target, 'actor' => actor, 'post' => payload }, base: RELAY_PATH
    end

    def relay_status
      request :get, '/status', base: RELAY_PATH
    end

    private

    def request(method, path, body = nil, base: API_PATH)
      uri = URI.parse "#{@server_url}#{base}#{path}"
      response = perform uri, build_request(method, uri, body)
      check_response! method, path, response
      response.body.present? ? JSON.parse(response.body) : {}
    rescue *NETWORK_ERRORS => e
      raise TransientError, "#{method.upcase} #{path}: #{e.class}: #{e.message}"
    rescue JSON::ParserError => e
      raise Error, "#{method.upcase} #{path}: invalid JSON response (#{e.message})"
    end

    def build_request(method, uri, body)
      request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Accept'] = 'application/json'
      if body
        request['Content-Type'] = 'application/json'
        request.body = body.to_json
      end
      request
    end

    def perform(uri, request)
      response = nil
      Net::HTTP.start uri.hostname, uri.port,
                      use_ssl: uri.scheme == 'https',
                      verify_mode: @verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE,
                      open_timeout: OPEN_TIMEOUT,
                      read_timeout: READ_TIMEOUT do |http|
        response = http.request request
      end
      response
    end

    # Le jeton et l'URL du serveur ne figurent jamais dans les messages d'erreur
    def check_response!(method, path, response)
      return if response.is_a? Net::HTTPSuccess

      message = "#{method.upcase} #{path}: HTTP #{response.code} #{api_error_message response}".strip
      raise TransientError, message if response.code.to_i == 429 || response.code.to_i >= 500

      raise Error, message
    end

    def api_error_message(response)
      JSON.parse(response.body.to_s)['message'].to_s
    rescue JSON::ParserError
      ''
    end

    def segment(value)
      ERB::Util.url_encode value.to_s
    end

    # Les identifiants dépendent du serveur et du bot : ils entrent dans la clé de cache
    def cached(key, &)
      namespace = Digest::SHA256.hexdigest("#{@server_url}|#{@token}")[0, 16]
      Rails.cache.fetch("redmine_mattermost/#{namespace}/#{key}", expires_in: CACHE_TTL, &)
    end
  end
end
