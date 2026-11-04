# frozen_string_literal: true

module RedmineMattermost
  # Mise en forme Markdown des messages Mattermost
  module Formatter
    ESCAPED_CHARACTERS = /([\\`*_~\[\]<>])/

    module_function

    # Échappe un texte court (nom, titre) pour qu'il s'affiche tel quel
    def escape(text)
      text.to_s.gsub(ESCAPED_CHARACTERS) { "\\#{Regexp.last_match 1}" }
    end

    def link(url, label)
      "[#{escape label}](#{url.to_s.gsub('(', '%28').gsub(')', '%29')})"
    end

    def bold(text)
      "**#{escape text}**"
    end

    # URL absolue d'un objet Redmine, construite comme dans les e-mails de Redmine
    def url_for(object, **options)
      Rails.application.routes.url_for object.event_url(Mailer.default_url_options.merge(options))
    end

    def object_link(object, label = object.to_s, **options)
      link url_for(object, **options), label
    end

    def field(title, value, short: true)
      { 'title' => title.to_s, 'value' => value.presence || '-', 'short' => short }
    end

    # Remplace les mentions @login par @nom Mattermost dans toutes les chaînes du payload
    def replace_mentions(value, usernames)
      case value
      when String
        usernames.reduce(value) { |text, (login, username)| text.gsub mention_pattern(login), "@#{username}" }
      when Hash then value.transform_values { |item| replace_mentions item, usernames }
      when Array then value.map { |item| replace_mentions item, usernames }
      else value
      end
    end

    # @login entier : ni précédé d'un mot ou d'un @, ni prolongé (un point final reste hors du login)
    def mention_pattern(login)
      /(?<![\w@])@#{Regexp.escape login}(?![\w@-]|\.\w)/i
    end

    # actor_message : variante sans auteur, publiée au nom de l'utilisateur par le relais
    # props : propriétés du post (redmine_issue_id, qui permet de reconnaître les réponses)
    def post(message, attachment = nil, actor_message: nil, props: {})
      payload = { 'message' => message }
      payload['actor_message'] = actor_message if actor_message.present?
      props = props.merge('attachments' => [attachment]) if attachment.present?
      payload['props'] = props if props.present?
      payload
    end
  end
end
