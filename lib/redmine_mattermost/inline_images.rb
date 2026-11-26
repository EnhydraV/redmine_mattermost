# frozen_string_literal: true

module RedmineMattermost
  # Images collées dans un texte (note, description) : la référence devient une image Markdown, à sa
  # place dans le message, servie par Redmine sur une URL signée (MattermostImagesController) que le
  # serveur et les applis Mattermost lisent sans session Redmine.
  # Un nom de fichier image sans chemin, retrouvé parmi les pièces jointes comme le fait Redmine
  # (InlineAttachmentsScrubber) ; une référence qui ne mène à aucune image jointe reste telle quelle.
  module InlineImages
    EXTENSIONS = 'avif|bmp|gif|jpg|jpeg|jpe|png|webp'
    PATTERNS = [
      # HTML, tel que le produit le collage d'image : <img style="..." src="clipboard-....png"><br>
      %r{<img\b[^>]*?\bsrc\s*=\s*(?<quote>["'])(?<name>[^/"']+?\.(?:#{EXTENSIONS}))\k<quote>[^>]*>(?:[ \t]*<br\s*/?>)?}io,
      # Markdown et CommonMark : ![alt](image.png "titre")
      %r{!\[[^\]]*\]\(\s*<?(?<name>[^/\s<>()]+?\.(?:#{EXTENSIONS}))>?(?:\s+(?:"[^"]*"|'[^']*'))?\s*\)}io,
      # Textile : !image.png!, !{width:50%}image.png(alt)!
      %r{!(?:\{[^\}]*\})?[<>=]?(?<name>[^/\s!(]+?\.(?:#{EXTENSIONS}))(?:\([^)]*\))?!}io
    ].freeze
    SERVABLE = /\.(?:#{EXTENSIONS})\z/io
    SIGNATURE_LENGTH = 32

    module_function

    def references?(text)
      text.present? && PATTERNS.any? { |pattern| pattern.match? text }
    end

    # Texte où chaque image jointe citée devient ![nom](URL signée). L'URL produite contient des « / » :
    # les motifs suivants, qui veulent un nom de fichier sans chemin, ne la reprennent pas.
    def embed(text, attachments)
      return text if text.blank? || attachments.blank?

      PATTERNS.reduce text do |result, pattern|
        result.gsub pattern do |reference|
          attachment = Attachment.latest_attach attachments, CGI.unescape(Regexp.last_match[:name])
          servable?(attachment) ? "![#{Formatter.escape attachment.filename}](#{url_for attachment})" : reference
        end
      end
    end

    # Images matricielles seulement : un SVG servi depuis le domaine de Redmine pourrait porter du script
    def servable?(attachment)
      attachment.present? && attachment.image? && SERVABLE.match?(attachment.filename)
    end

    def url_for(attachment)
      Rails.application.routes.url_helpers.mattermost_image_url(
        id: attachment.id, signature: signature(attachment), filename: attachment.filename,
        **Mailer.default_url_options
      )
    end

    # HMAC de l'identifiant et de l'empreinte du fichier, avec une clé dérivée de secret_key_base
    def signature(attachment)
      key = Rails.application.key_generator.generate_key 'redmine_mattermost/inline_images', 32
      OpenSSL::HMAC.hexdigest('SHA256', key, "#{attachment.id}/#{attachment.digest}")[0, SIGNATURE_LENGTH]
    end

    def valid_signature?(attachment, given)
      ActiveSupport::SecurityUtils.secure_compare signature(attachment), given.to_s
    end
  end
end
