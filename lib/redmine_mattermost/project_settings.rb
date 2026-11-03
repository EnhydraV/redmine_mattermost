# frozen_string_literal: true

module RedmineMattermost
  # Résolution d'un réglage : projet, puis projets parents, puis réglage global
  module ProjectSettings
    INHERIT = 0
    DISABLED = 1
    ENABLED = 2

    NO_CHANNEL = '-'

    class << self
      def text(project, name)
        text_from_projects(project, name) || RedmineMattermost.setting(name).to_s
      end

      # Valeur qui s'appliquerait si le projet ne surchargeait rien
      def inherited_text(project, name)
        text_from_projects(project&.parent, name) || RedmineMattermost.setting(name).to_s
      end

      def enabled?(project, name)
        flag = flag_from_projects project, name
        flag.nil? ? RedmineMattermost.setting?(name) : flag
      end

      def inherited_enabled?(project, name)
        flag = flag_from_projects project&.parent, name
        flag.nil? ? RedmineMattermost.setting?(name) : flag
      end

      # Liste des destinations : noms de canaux, ou @utilisateur pour un message direct
      def channels(project)
        parse_list text(project, :mattermost_channel)
      end

      def parse_list(value)
        return [] if value.blank? || value.strip == NO_CHANNEL

        value.split(',').map(&:strip).compact_blank.uniq
      end

      private

      def text_from_projects(project, name)
        while project
          value = project.mattermost_setting&.public_send name
          return value.strip if value.present?

          project = project.parent
        end
        nil
      end

      def flag_from_projects(project, name)
        while project
          flag = project.mattermost_setting&.public_send(name).to_i
          return flag == ENABLED unless flag == INHERIT

          project = project.parent
        end
        nil
      end
    end
  end
end
