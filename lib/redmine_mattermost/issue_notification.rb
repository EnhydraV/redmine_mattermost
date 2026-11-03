# frozen_string_literal: true

module RedmineMattermost
  # Notifications de création et de mise à jour d'un ticket
  class IssueNotification
    include Redmine::I18n

    def self.created(issue)
      new(issue).created
    end

    def self.updated(issue)
      new(issue).updated
    end

    def initialize(issue)
      @issue = issue
      @project = issue.project
    end

    def created
      return unless deliverable?

      payload = RedmineMattermost.with_default_language do
        message = l(:label_mattermost_issue_created,
                    project_url: project_link,
                    url: Formatter.object_link(@issue),
                    user: Formatter.bold(@issue.author))
        Formatter.post with_mentions(message, @issue, @issue.author), creation_attachment
      end
      Notifier.deliver @project, payload, users: direct_message_users(@issue, @issue.author), actor: @issue.author
    end

    def updated
      journal = @issue.current_journal
      return if journal.nil? || !deliverable? || !enabled?(:post_updates)
      return if journal.private_notes? && !enabled?(:post_private_notes)
      return if enabled?(:post_updates_reopened) && !reopened?(journal)

      payload = RedmineMattermost.with_default_language do
        message = l(:label_mattermost_issue_updated,
                    project_url: project_link,
                    url: Formatter.object_link(@issue, anchor: "change-#{journal.id}"),
                    user: Formatter.bold(journal.user))
        Formatter.post with_mentions(message, journal, journal.user), update_attachment(journal)
      end
      Notifier.deliver @project, payload, users: direct_message_users(journal, journal.user), actor: journal.user
    end

    private

    def deliverable?
      RedmineMattermost.configured? && (!@issue.is_private? || enabled?(:post_private_issues))
    end

    def enabled?(name)
      ProjectSettings.enabled? @project, name
    end

    def project_link
      Formatter.object_link @project, @project.name
    end

    def creation_attachment
      fields = [Formatter.field(l(:field_status), Formatter.escape(@issue.status)),
                Formatter.field(l(:field_priority), Formatter.escape(@issue.priority))]
      fields << Formatter.field(l(:field_assigned_to), Formatter.escape(@issue.assigned_to)) if @issue.assigned_to
      @issue.attachments.each do |attachment|
        fields << Formatter.field(l(:label_attachment), Formatter.object_link(attachment, attachment.filename))
      end
      if enabled?(:display_watchers) && @issue.watcher_users.any?
        fields << Formatter.field(l(:field_watcher), Formatter.escape(@issue.watcher_users.join(', ')))
      end

      attachment = { 'fallback' => @issue.to_s, 'fields' => fields }
      attachment['text'] = @issue.description if @issue.description.present? && enabled?(:new_include_description)
      attachment
    end

    def update_attachment(journal)
      fields = journal.details.filter_map { |detail| JournalField.for detail }
      fields << Formatter.field(l(:label_comment), journal.notes, short: false) if journal.notes.present?
      fields << Formatter.field(l(:field_private_notes), l(:general_text_Yes)) if journal.private_notes?
      fields << changeset_field(@issue.mattermost_changeset) if @issue.mattermost_changeset

      attachment = { 'fallback' => @issue.to_s, 'fields' => fields }
      description = new_description journal
      attachment['text'] = description if description.present? && enabled?(:updated_include_description)
      attachment
    end

    def new_description(journal)
      journal.details.detect { |detail| detail.property == 'attr' && detail.prop_key == 'description' }&.value
    end

    # Lien vers la révision quand le ticket est modifié par un mot-clé de commit
    def changeset_field(changeset)
      value = Formatter.object_link changeset, changeset.format_identifier
      comment = changeset.comments.to_s.lines.first.to_s.strip
      value = "#{value} #{Formatter.escape comment}" if comment.present?
      Formatter.field l(:label_revision), value, short: false
    end

    def reopened?(journal)
      detail = journal.details.detect { |d| d.property == 'attr' && d.prop_key == 'status_id' }
      return false if detail.nil?

      IssueStatus.find_by(id: detail.old_value)&.is_closed? && !IssueStatus.find_by(id: detail.value)&.is_closed?
    end

    # L'auteur de l'action n'est jamais mentionné : il serait notifié de son propre geste
    def with_mentions(message, mentionable, actor)
      names = ProjectSettings.parse_list ProjectSettings.text(@project, :default_mentions)
      names += mentioned_users(mentionable).map { |user| "@#{user.login}" } if enabled? :auto_mentions
      names = names.uniq(&:downcase)
      names.reject! { |name| name.casecmp? "@#{actor.login}" } if actor.respond_to?(:login) && actor.login.present?
      return message if names.empty?

      "#{message}\n#{l :label_mattermost_mentions, names: names.join(', ')}"
    end

    # Utilisateurs mentionnés dans le texte, tels que Redmine les a détectés
    def mentioned_users(mentionable)
      users = Array(mentionable.try(:mentioned_users))
      users.select { |user| @issue.visible? user }
    end

    def direct_message_users(source, actor)
      return [] unless enabled? :direct_messages

      (source.notified_users + source.notified_watchers).uniq - [actor]
    end
  end
end
