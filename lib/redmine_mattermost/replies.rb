# frozen_string_literal: true

module RedmineMattermost
  # Réponse écrite dans le fil d'une notification Mattermost, ajoutée en note au ticket
  module Replies
    class Refused < StandardError
      attr_reader :status

      def initialize(message, status)
        super(message)
        @status = status
      end
    end

    module_function

    # params : issue_id, username, email, message, root_id, channel_id
    def add_note(params)
      issue = Issue.find_by id: params[:issue_id]
      raise Refused.new('issue not found', :not_found) if issue.nil?

      user = user_for params[:username], params[:email]
      raise Refused.new('no Redmine account for this Mattermost user', :unprocessable_entity) if user.nil?
      raise Refused.new('not allowed to add notes to this issue', :forbidden) unless can_add_note? user, issue

      text = params[:message].to_s.strip
      raise Refused.new('empty message', :unprocessable_entity) if text.empty?

      save_note issue, user, text, params
    end

    # Même correspondance que le relais : login, puis adresse email
    def user_for(username, email)
      user = User.active.find_by(login: username.to_s) if username.present?
      user ||= User.having_mail(email.to_s).first if email.present?
      user if user&.active?
    end

    def can_add_note?(user, issue)
      issue.visible?(user) && user.allowed_to?(:add_issue_notes, issue.project)
    end

    def save_note(issue, user, text, params)
      previous_user = User.current
      User.current = user
      issue.init_journal user, text
      # La notification de cette note part dans le fil d'origine, à la place de la réponse
      issue.mattermost_reply_to = { 'root_id' => params[:root_id].to_s, 'channel_id' => params[:channel_id].to_s }
      raise Refused.new(issue.errors.full_messages.to_sentence, :unprocessable_entity) unless issue.save

      issue.journals.last
    ensure
      User.current = previous_user
    end
  end
end
