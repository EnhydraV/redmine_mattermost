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
  # payload : corps de POST /api/v4/posts, sans channel_id, plus actor_message (variante sans auteur)
  # actor : { 'username' => ..., 'email' => ... } pour publier au nom de l'utilisateur, via le plugin relais
  def perform(target, payload, actor = nil)
    client = RedmineMattermost::Client.from_settings
    return if client.nil?

    target = mattermost_target client, target
    payload = with_mattermost_mentions client, payload
    @actor_message = payload['actor_message']
    @reply_to = payload['reply_to']
    payload = payload.except 'actor_message', 'reply_to'
    return if actor.present? && relayed?(client, target, actor, payload)

    channel_id = client.channel_id_for target
    client.create_post payload.merge('channel_id' => channel_id).merge(thread_for(channel_id))
  end

  def target_label
    target = arguments.first || {}
    target['username'].present? ? "@#{target['username']}" : "#{target['team']}/#{target['channel']}"
  end

  private

  # Une note née d'une réponse rejoint son fil, dans le canal de ce fil seulement
  def thread_for(channel_id)
    @reply_to && @reply_to['channel_id'] == channel_id ? { 'root_id' => @reply_to['root_id'] } : {}
  end

  # Destinataire d'un message direct : login Redmine converti en nom Mattermost
  def mattermost_target(client, target)
    return target if target['email'].blank?

    { 'username' => client.username_for(target['username'], target['email']) || target['username'] }
  end

  # Mentions @login converties en @nom Mattermost ; un utilisateur introuvable garde son @login
  def with_mattermost_mentions(client, payload)
    users = payload['mention_users']
    payload = payload.except 'mention_users'
    return payload if users.blank?

    usernames = users.each_with_object({}) do |user, found|
      username = client.username_for user['login'], user['email']
      found[user['login']] = username if username && !username.casecmp?(user['login'])
    rescue RedmineMattermost::Client::Error => e
      Rails.logger.warn "[redmine_mattermost] mention @#{user['login']} kept as is: #{e.message}"
    end
    usernames.empty? ? payload : RedmineMattermost::Formatter.replace_mentions(payload, usernames)
  end

  # Plugin absent ou refus : le bot publie lui-même, la notification n'est pas perdue
  # Le post de l'utilisateur porte la variante sans auteur ; le relais garde le message complet
  # pour le cas où il publie au nom du bot, et le fil d'origine d'une note née d'une réponse
  def relayed?(client, target, actor, payload)
    options = { reply_to: @reply_to }.compact
    if @actor_message.present?
      options[:bot_message] = payload['message']
      payload = payload.merge 'message' => @actor_message
    end
    client.relay_post target, actor, payload, **options
    true
  rescue RedmineMattermost::Client::TransientError
    raise
  rescue RedmineMattermost::Client::Error => e
    Rails.logger.warn "[redmine_mattermost] relay to #{target_label} failed, posting as the bot: #{e.message}"
    false
  end
end
