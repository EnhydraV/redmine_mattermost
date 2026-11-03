# frozen_string_literal: true

# Reprise des réglages de redmine_messenger (AlphaNodes) ou redmine_messenger_so (Smart/Origin).
# Les URL de webhook ne sont pas reprises : la connexion passe par un bot.
# Les données d'origine restent en place, l'ancien plugin se désinstalle ensuite.
class ImportMessengerSettings < ActiveRecord::Migration[7.2]
  class LegacyProjectSetting < ActiveRecord::Base
    self.table_name = 'messenger_settings'
  end

  class ProjectSetting < ActiveRecord::Base
    self.table_name = 'mattermost_settings'
  end

  class GlobalSetting < ActiveRecord::Base
    self.table_name = 'settings'
  end

  LEGACY_PLUGIN_SETTINGS = %w[plugin_redmine_messenger_so plugin_redmine_messenger].freeze

  FLAGS = %w[auto_mentions
             display_watchers
             post_updates
             post_updates_reopened
             new_include_description
             updated_include_description
             post_private_issues
             post_private_notes
             post_wiki
             post_wiki_updates].freeze

  RENAMED = { 'messenger_channel' => 'mattermost_channel',
              'messenger_direct_users_messages' => 'direct_messages' }.freeze

  def up
    import_project_settings if table_exists? :messenger_settings
    import_global_settings
  end

  def down
    # Rien à défaire : la table mattermost_settings disparaît avec la migration 001
  end

  private

  def import_project_settings
    return if ProjectSetting.exists?

    LegacyProjectSetting.order(:id).each do |legacy|
      next if ProjectSetting.exists? project_id: legacy.project_id

      ProjectSetting.create! convert(legacy.attributes).merge('project_id' => legacy.project_id)
    end
  end

  def import_global_settings
    return if GlobalSetting.exists? name: 'plugin_redmine_mattermost'

    legacy = LEGACY_PLUGIN_SETTINGS.lazy.filter_map { |name| legacy_global_values name }.first
    return if legacy.nil?

    values = convert legacy
    values['mattermost_verify_ssl'] = legacy['messenger_verify_ssl'] if legacy.key? 'messenger_verify_ssl'
    defaults = RedmineMattermost.loader.default_settings.stringify_keys
    Setting.plugin_redmine_mattermost = ActiveSupport::HashWithIndifferentAccess.new defaults.merge(values)
  end

  def convert(attributes)
    values = attributes.slice(*FLAGS, 'default_mentions')
    RENAMED.each { |old_name, new_name| values[new_name] = attributes[old_name] if attributes.key? old_name }
    values.compact
  end

  def legacy_global_values(name)
    raw = GlobalSetting.find_by(name: name)&.value
    return if raw.blank?

    values = YAML.safe_load raw, permitted_classes: Rails.configuration.active_record.yaml_column_permitted_classes
    values.respond_to?(:to_h) ? values.to_h.stringify_keys : nil
  rescue Psych::Exception
    nil
  end
end
