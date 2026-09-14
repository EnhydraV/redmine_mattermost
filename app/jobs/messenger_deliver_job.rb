# frozen_string_literal: true

require 'net/http'
require 'uri'

class MessengerDeliverJob < ActiveJob::Base
  queue_as :default

  def perform(url, params)
    uri = URI url
    http_options = { use_ssl: uri.scheme == 'https' }
    http_options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE unless RedmineMessengerSo.setting? :messenger_verify_ssl
    begin
      req = Net::HTTP::Post.new uri
      req.set_form_data payload: params.to_json
      Net::HTTP.start uri.hostname, uri.port, http_options do |http|
        response = http.request req
        Rails.logger.warn response.inspect unless response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
      end
    rescue StandardError => e
      Rails.logger.warn "cannot connect to #{url}"
      Rails.logger.warn e
    end
  end
end
