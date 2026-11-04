# frozen_string_literal: true

module RedmineMattermost
  # Attributs dont les modifications ne sont pas publiées (réglage global ignored_attributes).
  # Clés : nom de l'attribut (done_ratio), cf_<id> pour un champ personnalisé,
  # attachment et relation pour les fichiers et les relations.
  module IgnoredAttributes
    CORE_ATTRIBUTES = %w[project_id tracker_id subject description status_id priority_id assigned_to_id
                         category_id fixed_version_id parent_id start_date due_date estimated_hours
                         done_ratio is_private].freeze

    class << self
      include Redmine::I18n

      def keys
        Array(RedmineMattermost.setting(:ignored_attributes)).map(&:to_s).compact_blank
      end

      def key_for(detail)
        case detail.property
        when 'attr' then detail.prop_key.to_s
        when 'cf' then "cf_#{detail.prop_key}"
        else detail.property.to_s
        end
      end

      # Détails d'un journal qui restent à publier
      def reported(details, ignored = keys)
        return details.to_a if ignored.empty?

        details.reject { |detail| ignored.include? key_for(detail) }
      end

      # Choix groupés pour la page de configuration
      def choices
        attributes = CORE_ATTRIBUTES.map { |key| [attribute_label(key), key] }
        attributes += [[l(:label_attachment_plural), 'attachment'], [l(:label_related_issues), 'relation']]
        custom_fields = IssueCustomField.sorted.map { |field| [field.name, "cf_#{field.id}"] }
        { l(:label_attribute_plural) => attributes, l(:label_custom_field_plural) => custom_fields }
      end

      private

      def attribute_label(key)
        name = key.delete_suffix '_id'
        name == 'parent' ? l(:field_parent_issue) : l(:"field_#{name}")
      end
    end
  end
end
