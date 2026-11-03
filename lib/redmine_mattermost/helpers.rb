# frozen_string_literal: true

module RedmineMattermost
  module Helpers
    def project_mattermost_options(active)
      options_for_select({ l(:field_is_default) => RedmineMattermost::ProjectSettings::INHERIT.to_s,
                           l(:label_mattermost_settings_disabled) => RedmineMattermost::ProjectSettings::DISABLED.to_s,
                           l(:label_mattermost_settings_enabled) => RedmineMattermost::ProjectSettings::ENABLED.to_s },
                         active.to_s)
    end

    def project_setting_mattermost_default_value(name)
      if RedmineMattermost::ProjectSettings.inherited_enabled? @project, name
        l :label_mattermost_settings_enabled
      else
        l :label_mattermost_settings_disabled
      end
    end

    def project_setting_mattermost_default_text(name)
      RedmineMattermost::ProjectSettings.inherited_text(@project, name).presence || '-'
    end
  end
end
