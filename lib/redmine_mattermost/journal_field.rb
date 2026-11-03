# frozen_string_literal: true

module RedmineMattermost
  # Conversion d'un JournalDetail en champ d'attachment Mattermost
  class JournalField
    include Redmine::I18n

    OBJECT_ATTRIBUTES = {
      'tracker_id' => 'Tracker',
      'project_id' => 'Project',
      'status_id' => 'IssueStatus',
      'priority_id' => 'IssuePriority',
      'category_id' => 'IssueCategory',
      'assigned_to_id' => 'Principal',
      'author_id' => 'Principal',
      'fixed_version_id' => 'Version'
    }.freeze

    ISSUE_ATTRIBUTES = %w[parent_id copied_from_id].freeze
    LONG_ATTRIBUTES = %w[subject].freeze
    BOOLEAN_ATTRIBUTES = %w[is_private].freeze

    def self.for(detail)
      new(detail).to_h
    end

    def initialize(detail)
      @detail = detail
    end

    # nil quand le détail n'a pas à figurer dans le message
    def to_h
      case @detail.property
      when 'attr' then attribute_field
      when 'cf' then custom_field_field
      when 'attachment' then attachment_field
      end
    end

    private

    def attribute_field
      key = @detail.prop_key.to_s
      return if key == 'description'

      Formatter.field attribute_title(key), attribute_value(key), short: LONG_ATTRIBUTES.exclude?(key)
    end

    def attribute_title(key)
      name = key.delete_suffix '_id'
      case name
      when 'parent' then l(:field_parent_issue)
      when 'copied_from' then l(:label_copied_from)
      else l :"field_#{name}"
      end
    end

    def attribute_value(key)
      value = @detail.value
      return if value.blank?

      if OBJECT_ATTRIBUTES.key? key
        Formatter.escape(OBJECT_ATTRIBUTES[key].constantize.find_by(id: value) || value)
      elsif ISSUE_ATTRIBUTES.include? key
        issue_value value
      elsif key == 'estimated_hours'
        Formatter.escape format_hours(value.is_a?(String) ? (value.to_hours || value) : value)
      elsif BOOLEAN_ATTRIBUTES.include? key
        l(RedminePluginKit.true?(value) ? :general_text_Yes : :general_text_No)
      else
        Formatter.escape value
      end
    end

    def issue_value(id)
      issue = Issue.find_by id: id
      issue ? Formatter.object_link(issue) : Formatter.escape("##{id}")
    end

    # Seuls les champs personnalisés visibles par tous sont publiés
    def custom_field_field
      custom_field = @detail.custom_field
      return if custom_field.nil? || !custom_field.visible?

      value = @detail.value.presence && IssuesController.helpers.format_value(@detail.value, custom_field)
      Formatter.field custom_field.name, Formatter.escape(value)
    end

    def attachment_field
      attachment = Attachment.find_by id: @detail.prop_key
      value = if attachment
                Formatter.object_link attachment, attachment.filename
              elsif @detail.value.present?
                Formatter.escape @detail.value
              elsif @detail.old_value.present?
                "~~#{Formatter.escape @detail.old_value}~~"
              end
      Formatter.field l(:label_attachment), value
    end
  end
end
