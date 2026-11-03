# frozen_string_literal: true

loader = RedminePluginKit::Loader.new plugin_id: 'redmine_mattermost'

Redmine::Plugin.register :redmine_mattermost do
  name 'Mattermost'
  author 'Vincent Vanwaelscappel'
  url 'https://github.com/EnhydraV/redmine_mattermost'
  author_url 'https://github.com/EnhydraV'
  description 'Posts Redmine issue and wiki notifications to Mattermost through a bot account'
  version RedmineMattermost::VERSION

  requires_redmine version_or_higher: '6.0.0'

  permission :manage_mattermost, projects: :settings, mattermost_settings: :update

  settings default: loader.default_settings, partial: 'settings/mattermost_settings'
end

RedminePluginKit::Loader.persisting { loader.load_model_hooks! }
