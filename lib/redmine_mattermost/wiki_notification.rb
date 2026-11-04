# frozen_string_literal: true

module RedmineMattermost
  # Notifications de création et de modification d'une page wiki
  class WikiNotification
    include Redmine::I18n

    def self.created(content)
      new(content).deliver :post_wiki, :label_mattermost_wiki_created
    end

    def self.updated(content)
      new(content).deliver :post_wiki_updates, :label_mattermost_wiki_updated
    end

    def initialize(content)
      @content = content
      @page = content.page
      @project = content.project
    end

    def deliver(setting, label)
      return unless RedmineMattermost.configured? && ProjectSettings.enabled?(@project, setting)

      payload = RedmineMattermost.with_default_language do
        args = { project_url: Formatter.object_link(@project, @project.name),
                 url: Formatter.object_link(@page, @page.pretty_title) }
        message = l(label, **args, user: Formatter.bold(@content.author))
        # Version sans auteur, pour le post publié au nom de l'utilisateur par le relais
        actor_message = l :"#{label}_short", **args if RedmineMattermost.actor_for @content.author
        Formatter.post message, comments_attachment, actor_message: actor_message
      end
      Notifier.deliver @project, payload, actor: @content.author
    end

    private

    def comments_attachment
      return if @content.comments.blank?

      { 'fallback' => @content.comments.to_s, 'text' => @content.comments.to_s }
    end
  end
end
