# frozen_string_literal: true

module RedmineMattermost
  module Patches
    # Le texte d'une page vit dans WikiContent : c'est lui qui est enregistré à chaque modification
    module WikiContentPatch
      extend ActiveSupport::Concern

      included do
        after_create_commit :send_mattermost_create
        after_update_commit :send_mattermost_update
      end

      def send_mattermost_create
        RedmineMattermost.safely("wiki content ##{id} created") { RedmineMattermost::WikiNotification.created self }
      end

      def send_mattermost_update
        RedmineMattermost.safely("wiki content ##{id} updated") { RedmineMattermost::WikiNotification.updated self }
      end
    end
  end
end
