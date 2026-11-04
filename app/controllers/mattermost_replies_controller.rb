# frozen_string_literal: true

# Appelé par le plugin Mattermost avec le secret partagé, hors session Redmine
class MattermostRepliesController < ActionController::API
  AUTH_HEADER = 'X-Redmine-Mattermost-Secret'

  before_action :authenticate

  def create
    journal = RedmineMattermost::Replies.add_note params.permit(:issue_id, :username, :email, :message,
                                                                :root_id, :channel_id)
    render json: { journal_id: journal.id }, status: :created
  rescue RedmineMattermost::Replies::Refused => e
    render json: { message: e.message }, status: e.status
  end

  private

  # Secret absent ou faux : la route n'existe pas pour l'appelant
  def authenticate
    secret = RedmineMattermost.reply_secret
    given = request.headers[AUTH_HEADER].to_s
    head :not_found unless secret && ActiveSupport::SecurityUtils.secure_compare(given, secret)
  end
end
