# frozen_string_literal: true

module RedmineMattermost
  module Patches
    module ProjectPatch
      extend ActiveSupport::Concern

      included do
        has_one :mattermost_setting, dependent: :destroy
      end
    end
  end
end
