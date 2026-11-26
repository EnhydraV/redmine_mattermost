# frozen_string_literal: true

# Images collées dans les notes, lues par le serveur et les applis Mattermost sans session Redmine :
# l'URL signée par RedmineMattermost::InlineImages tient lieu d'autorisation
class MattermostImagesController < ActionController::API
  def show
    attachment = Attachment.find_by id: params[:id]
    return head :not_found unless servable? attachment

    response.headers['Content-Security-Policy'] = "default-src 'none'; sandbox"
    response.headers['X-Content-Type-Options'] = 'nosniff'
    expires_in 1.day
    send_file attachment.diskfile, filename: attachment.filename, disposition: 'inline',
                                   type: Redmine::MimeType.of(attachment.filename) || 'application/octet-stream'
  end

  private

  def servable?(attachment)
    RedmineMattermost::InlineImages.servable?(attachment) && attachment.readable? &&
      RedmineMattermost::InlineImages.valid_signature?(attachment, params[:signature])
  end
end
