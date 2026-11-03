# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__
require File.expand_path '../../../db/migrate/002_import_messenger_settings', __FILE__

class ImportMessengerSettingsTest < ActiveSupport::TestCase
  fixtures :projects

  # Réglage laissé en 2016 par altsol/redmine_mattermost, tel qu'on le trouve encore en production
  ALTSOL_SETTINGS = <<~YAML
    --- !ruby/hash-with-ivars:ActionController::Parameters
    elements:
      mattermost_url: https://slack.example.com/hooks/old
      channel: redmine
      username: redmine
    ivars:
      :@permitted: false
  YAML

  MESSENGER_SETTINGS = { 'messenger_url' => 'https://chat.example.com/hooks/abc123',
                         'messenger_channel' => 'redmine-test',
                         'messenger_verify_ssl' => '1',
                         'auto_mentions' => '1',
                         'default_mentions' => '',
                         'post_updates' => '1' }.freeze

  def setup
    create_alphanodes_table
    Setting.where(name: %w[plugin_redmine_mattermost plugin_redmine_messenger]).delete_all
    Setting.clear_cache
  end

  def teardown
    ActiveRecord::Base.connection.drop_table :messenger_settings, if_exists: true
    Setting.clear_cache
  end

  def test_project_channels_and_options_are_imported
    insert_legacy_project 1, messenger_channel: 'cookbook', default_mentions: '@charlie', post_updates: 2,
                             messenger_direct_users_messages: 1
    insert_legacy_project 2, messenger_channel: '-'
    insert_legacy_project 3, messenger_channel: ''

    migrate

    first = MattermostSetting.find_by project_id: 1
    assert_equal 'cookbook', first.mattermost_channel
    assert_equal '@charlie', first.default_mentions
    assert_equal 2, first.post_updates
    assert_equal 1, first.direct_messages
    assert_equal 0, first.post_wiki
    assert_equal '-', MattermostSetting.find_by(project_id: 2).mattermost_channel
    assert_equal '', MattermostSetting.find_by(project_id: 3).mattermost_channel
  end

  def test_project_import_is_skipped_once_settings_exist
    MattermostSetting.create! project_id: 1, mattermost_channel: 'oscar'
    insert_legacy_project 2, messenger_channel: 'juliette'

    migrate

    assert_nil MattermostSetting.find_by(project_id: 2)
  end

  def test_global_settings_replace_an_altsol_leftover
    store_raw_setting 'plugin_redmine_mattermost', ALTSOL_SETTINGS
    store_messenger_settings MESSENGER_SETTINGS

    migrate

    settings = Setting.plugin_redmine_mattermost
    assert_equal 'https://chat.example.com', settings['mattermost_url']
    assert_equal 'redmine-test', settings['mattermost_channel']
    assert_equal '1', settings['auto_mentions']
    assert_equal '1', settings['mattermost_verify_ssl']
    assert_equal '', settings['mattermost_team']
    assert_not settings.key?('channel')
  end

  def test_altsol_leftover_is_reset_without_messenger_settings
    store_raw_setting 'plugin_redmine_mattermost', ALTSOL_SETTINGS

    migrate

    assert_equal '', Setting.plugin_redmine_mattermost['mattermost_url']
  end

  def test_settings_of_this_plugin_are_kept
    Setting.plugin_redmine_mattermost = ActiveSupport::HashWithIndifferentAccess.new(
      'mattermost_url' => 'https://victor.example.com', 'mattermost_team' => 'dev'
    )
    store_messenger_settings MESSENGER_SETTINGS

    migrate

    assert_equal 'https://victor.example.com', Setting.plugin_redmine_mattermost['mattermost_url']
  end

  def test_server_url_keeps_a_sub_path
    store_messenger_settings MESSENGER_SETTINGS.merge('messenger_url' => 'https://example.com/chat/hooks/abc')

    migrate

    assert_equal 'https://example.com/chat', Setting.plugin_redmine_mattermost['mattermost_url']
  end

  private

  def migrate
    ActiveRecord::Migration.suppress_messages { ImportMessengerSettings.new.up }
    Setting.clear_cache
  end

  # Schéma de redmine_messenger (AlphaNodes), migrations 001 à 004
  def create_alphanodes_table
    ActiveRecord::Base.connection.create_table :messenger_settings, force: true do |t|
      t.references :project, null: false
      t.string :messenger_url, :messenger_icon, :messenger_channel, :messenger_username, :default_mentions
      %i[messenger_verify_ssl auto_mentions display_watchers post_updates new_include_description
         updated_include_description post_private_issues post_private_notes post_wiki post_wiki_updates
         post_db post_db_updates post_contact post_contact_updates post_password post_password_updates
         post_private_contacts post_private_db messenger_direct_users_messages].each do |flag|
        t.integer flag, default: 0, null: false
      end
    end
    ImportMessengerSettings::LegacyProjectSetting.reset_column_information
  end

  def insert_legacy_project(project_id, attributes)
    ImportMessengerSettings::LegacyProjectSetting.create! attributes.merge(project_id: project_id)
  end

  # Le plugin d'origine n'est pas chargé : son réglage est écrit tel qu'il l'enregistrait
  def store_messenger_settings(values)
    store_raw_setting 'plugin_redmine_messenger', ActiveSupport::HashWithIndifferentAccess.new(values).to_yaml
  end

  def store_raw_setting(name, raw)
    ImportMessengerSettings::GlobalSetting.create! name: name, value: raw, updated_on: Time.current
  end
end
