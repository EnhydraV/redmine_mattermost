# frozen_string_literal: true

module RedmineMattermost
  module Hooks
    class ModelHook < Redmine::Hook::Listener
      def after_plugins_loaded(_context = {})
        RedmineMattermost.setup!
      end

      # Appelé avant issue.save : la notification de mise à jour portera le lien vers la révision
      def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context = {})
        issue = context[:issue]
        issue.mattermost_changeset = context[:changeset] if issue.respond_to? :mattermost_changeset=
      end
    end
  end
end
