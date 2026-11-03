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
        message = l(label,
                    project_url: Formatter.object_link(@project, @project.name),
                    url: Formatter.object_link(@page, @page.pretty_title),
                    user: Formatter.bold(@content.author))
        Formatter.post message, comments_attachment
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
