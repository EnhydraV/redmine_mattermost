# frozen_string_literal: true

module RedmineMattermost
  # Calcule les destinations d'un message et met un envoi en file pour chacune
  module Notifier
    module_function

    def deliver(project, payload, users: [], actor: nil)
      targets = (channel_targets(project) + user_targets(users)).uniq
      actor_identity = RedmineMattermost.actor_for actor
      targets.each { |target| MattermostDeliverJob.perform_later target, payload, actor_identity }
      targets
    end

    def channel_targets(project)
      team = ProjectSettings.text project, :mattermost_team
      ProjectSettings.channels(project).filter_map do |name|
        if name.start_with? '@'
          { 'username' => name.delete_prefix('@') }
        elsif team.present?
          { 'team' => team, 'channel' => name }
        else
          Rails.logger.warn "[redmine_mattermost] no team configured for project #{project.identifier}, channel #{name} ignored"
          nil
        end
      end
    end

    def user_targets(users)
      users.filter_map do |user|
        { 'username' => user.login, 'email' => user.mail.to_s } if user.respond_to?(:login) && user.login.present?
      end
    end
  end
end
