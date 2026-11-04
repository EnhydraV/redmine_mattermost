# frozen_string_literal: true

module RedmineMattermost
  VERSION = '2.1.0'

  # Variable d'environnement prioritaire sur le jeton saisi dans l'administration
  BOT_TOKEN_ENV = 'REDMINE_MATTERMOST_BOT_TOKEN'

  # Secret partagé avec le plugin Mattermost, qui transmet les réponses aux notifications
  REPLY_SECRET_ENV = 'REDMINE_MATTERMOST_REPLY_SECRET'

  # Plugin serveur Mattermost (dépôt EnhydraV/mattermost-plugin-redmine) qui publie au nom de l'utilisateur
  RELAY_PLUGIN_ID = 'com.cubedesigners.redmine'

  include RedminePluginKit::PluginBase

  class << self
    def configured?
      server_url.present? && bot_token.present?
    end

    def server_url
      setting(:mattermost_url).to_s.strip.chomp('/')
    end

    def bot_token
      ENV.fetch(BOT_TOKEN_ENV, nil).presence || setting(:mattermost_bot_token).to_s.strip
    end

    def bot_token_from_env?
      ENV.fetch(BOT_TOKEN_ENV, nil).present?
    end

    # Sans secret, les réponses venues de Mattermost sont refusées
    def reply_secret
      ENV.fetch(REPLY_SECRET_ENV, nil).presence
    end

    # Identité transmise au plugin relais, ou nil pour publier en tant que bot
    def actor_for(user)
      return unless setting?(:post_as_actor) && user.is_a?(User) && user.login.present?

      { 'username' => user.login, 'email' => user.mail.to_s }
    end

    # Les messages sont rédigés dans la langue par défaut de Redmine
    def with_default_language(&)
      locale = Setting.default_language.to_s
      locale = 'en' unless ::I18n.available_locales.map(&:to_s).include? locale
      ::I18n.with_locale(locale, &)
    end

    # Une notification ne doit jamais faire échouer l'enregistrement d'un ticket ou d'une page
    def safely(context)
      yield
    rescue StandardError => e
      Rails.logger.error "[redmine_mattermost] #{context}: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n") if e.backtrace
      nil
    end

    private

    def setup
      loader.add_patch %w[Issue
                          Project
                          WikiContent]

      loader.add_helper [{ controller: 'Projects', helper: 'MattermostProjects' }]

      loader.add_global_helper RedmineMattermost::Helpers

      loader.apply!
    end
  end
end
