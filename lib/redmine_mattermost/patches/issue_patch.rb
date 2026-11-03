# frozen_string_literal: true

module RedmineMattermost
  module Patches
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        # Révision qui a déclenché la mise à jour (mot-clé de commit), posée par ModelHook
        attr_accessor :mattermost_changeset

        after_create_commit :send_mattermost_create
        after_update_commit :send_mattermost_update
      end

      def send_mattermost_create
        RedmineMattermost.safely("issue ##{id} created") { RedmineMattermost::IssueNotification.created self }
      end

      def send_mattermost_update
        RedmineMattermost.safely("issue ##{id} updated") { RedmineMattermost::IssueNotification.updated self }
      ensure
        self.mattermost_changeset = nil
      end
    end
  end
end
