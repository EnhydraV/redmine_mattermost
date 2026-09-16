# frozen_string_literal: true

module RedmineMessengerSo
  VERSION = '1.1.2'

  include RedminePluginKit::PluginBase

  class << self
    private

    def setup
      # Patches
      loader.add_patch %w[Issue
                          Project
                          WikiPage]

      # Helper
      loader.add_helper [{ controller: 'Projects', helper: 'MessengerProjects' }]

      # Global helpers
      loader.add_global_helper RedmineMessengerSo::Helpers

      # Apply patches and helper
      loader.apply!
    end
  end
end
