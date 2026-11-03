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

    def post(message, attachment = nil)
      payload = { 'message' => message }
      payload['props'] = { 'attachments' => [attachment] } if attachment.present?
      payload
    end
  end
end
