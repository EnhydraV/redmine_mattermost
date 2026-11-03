# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start :rails do
    add_filter 'init.rb'
    root File.expand_path "#{File.dirname __FILE__}/.."
  end
end

require File.expand_path "#{File.dirname __FILE__}/../../../test/test_helper"

module RedmineMattermost
  module TestHelper
    include ActiveJob::TestHelper

    # Redmine force l'adaptateur :inline en test, que TestHelper respecte depuis Rails 7.2
    def queue_adapter_for_test
      ActiveJob::QueueAdapters::TestAdapter.new
    end

    BASE_SETTINGS = { 'mattermost_url' => 'https://chat.example.com',
                      'mattermost_bot_token' => 'bot-token',
                      'mattermost_team' => 'dev',
                      'mattermost_channel' => 'redmine' }.freeze

    def with_mattermost_settings(overrides = {}, &)
      values = RedmineMattermost.loader.default_settings.stringify_keys
                                .merge(BASE_SETTINGS)
                                .merge(overrides.stringify_keys)
      with_settings plugin_redmine_mattermost: ActiveSupport::HashWithIndifferentAccess.new(values), &
    end

    # Envois mis en file : [[target, payload, actor], ...]
    def mattermost_deliveries
      jobs = enqueued_jobs.select { |job| job[:job] == MattermostDeliverJob }
      jobs.map! { |job| ActiveJob::Arguments.deserialize job[:args] }
    end

    def mattermost_payloads
      payloads = mattermost_deliveries.map(&:second)
      payloads.uniq!
      payloads
    end

    def attachment_fields(payload)
      payload.dig('props', 'attachments', 0, 'fields') || []
    end

    def set_project_setting(project, attributes)
      setting = MattermostSetting.find_or_initialize_by project_id: project.id
      setting.update! attributes
      project.reload
    end
  end
end
