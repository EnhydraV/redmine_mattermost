# frozen_string_literal: true

class MattermostDeliverJob < ApplicationJob
  queue_as :default

  rescue_from RedmineMattermost::Client::Error do |error|
    Rails.logger.warn "[redmine_mattermost] delivery to #{target_label} failed: #{error.message}"
  end

  retry_on RedmineMattermost::Client::TransientError, wait: 30.seconds, attempts: 3 do |job, error|
    Rails.logger.warn "[redmine_mattermost] delivery to #{job.target_label} abandoned: #{error.message}"
  end

  # target : { 'team' => ..., 'channel' => ... } ou { 'username' => ... }
  # payload : corps de POST /api/v4/posts, sans channel_id
  # actor : { 'username' => ..., 'email' => ... } pour publier au nom de l'utilisateur, via le plugin relais
  def perform(target, payload, actor = nil)
    client = RedmineMattermost::Client.from_settings
    return if client.nil?
    return if actor.present? && relayed?(client, target, actor, payload)

    client.create_post payload.merge('channel_id' => client.channel_id_for(target))
  end

  def target_label
    target = arguments.first || {}
    target['username'].present? ? "@#{target['username']}" : "#{target['team']}/#{target['channel']}"
  end

  private

  # Plugin absent ou refus : le bot publie lui-même, la notification n'est pas perdue
  def relayed?(client, target, actor, payload)
    client.relay_post target, actor, payload
    true
  rescue RedmineMattermost::Client::TransientError
    raise
  rescue RedmineMattermost::Client::Error => e
    Rails.logger.warn "[redmine_mattermost] relay to #{target_label} failed, posting as the bot: #{e.message}"
    false
  end
end
