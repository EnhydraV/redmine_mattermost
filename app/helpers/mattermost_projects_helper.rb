# frozen_string_literal: true

module MattermostProjectsHelper
  def project_settings_tabs
    tabs = super

    if User.current.allowed_to? :manage_mattermost, @project
      tabs << { name: 'mattermost',
                action: :manage_mattermost,
                partial: 'mattermost_settings/show',
                label: :label_mattermost }
    end

    tabs
  end
end
