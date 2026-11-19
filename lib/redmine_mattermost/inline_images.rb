# frozen_string_literal: true

module RedmineMattermost
  # Images collées dans un texte (note, description) : retirées du texte et jointes au post par le relais.
  # Un nom de fichier image sans chemin, retrouvé parmi les pièces jointes comme le fait Redmine
  # (InlineAttachmentsScrubber) ; une référence qui ne mène à aucune image jointe reste dans le texte.
  module InlineImages
    MAX_FILES = 5
    MAX_FILE_SIZE = 10.megabytes

    EXTENSIONS = 'avif|bmp|gif|jpg|jpeg|jpe|png|webp'
    PATTERNS = [
      # HTML, tel que le produit le collage d'image : <img style="..." src="clipboard-....png"><br>
      %r{<img\b[^>]*?\bsrc\s*=\s*(?<quote>["'])(?<name>[^/"']+?\.(?:#{EXTENSIONS}))\k<quote>[^>]*>(?:[ \t]*<br\s*/?>)?}io,
      # Markdown et CommonMark : ![alt](image.png "titre")
      %r{!\[[^\]]*\]\(\s*<?(?<name>[^/\s<>()]+?\.(?:#{EXTENSIONS}))>?(?:\s+(?:"[^"]*"|'[^']*'))?\s*\)}io,
      # Textile : !image.png!, !{width:50%}image.png(alt)!
      %r{!(?:\{[^\}]*\})?[<>=]?(?<name>[^/\s!(]+?\.(?:#{EXTENSIONS}))(?:\([^)]*\))?!}io
    ].freeze

    module_function

    def references?(text)
      text.present? && PATTERNS.any? { |pattern| pattern.match? text }
    end

    # [texte sans les images trouvées, pièces jointes de ces images]
    def extract(text, attachments)
      found = []
      return [text, found] if text.blank? || attachments.blank?

      cleaned = PATTERNS.reduce text do |result, pattern|
        result.gsub pattern do |reference|
          attachment = Attachment.latest_attach attachments, CGI.unescape(Regexp.last_match[:name])
          next reference unless attachment&.image?

          found << attachment
          ''
        end
      end
      [cleaned.strip, found.uniq]
    end

    # Entrées du payload : le job lit le fichier, ou se rabat sur le lien
    def entries(attachments)
      attachments.uniq.map! do |attachment|
        { 'id' => attachment.id, 'name' => attachment.filename,
          'link' => Formatter.object_link(attachment, attachment.filename) }
      end
    end

    # Contenu en base64 pour le relais ; nil quand le fichier manque ou dépasse la taille admise
    def read(id)
      attachment = Attachment.find_by id: id
      return if attachment.nil? || !attachment.readable? || attachment.filesize > MAX_FILE_SIZE

      Base64.strict_encode64 File.binread(attachment.diskfile)
    end
  end
end
