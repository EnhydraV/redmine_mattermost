# frozen_string_literal: true

module RedmineMessengerSo
  module Patches
    module WikiPagePatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        after_create_commit :send_messenger_create
        after_update_commit :send_messenger_update
      end

      module InstanceMethods
        def send_messenger_create
          return unless Messenger.setting_for_project project, :post_wiki

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url

          initial_language = ::I18n.locale
          begin
            set_language_if_valid Setting.default_language

            Messenger.speak l(:label_messenger_wiki_created,
                              project_url: Messenger.project_url_markdown(project),
                              url: Messenger.url_markdown(self, title),
                              user: User.current),
                            channels, url, project: project
          ensure
            ::I18n.locale = initial_language
          end
        end

        def send_messenger_update
          return unless Messenger.setting_for_project project, :post_wiki_updates

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url

          initial_language = ::I18n.locale
          begin
            set_language_if_valid Setting.default_language

            attachment = nil
            if !content.nil? && content.comments.present?
              attachment = {}
              attachment[:text] = Messenger.markup_format content.comments.to_s
            end

            Messenger.speak l(:label_messenger_wiki_updated,
                              project_url: Messenger.project_url_markdown(project),
                              url: Messenger.url_markdown(self, title),
                              user: content.author),
                            channels, url, project: project, attachment: attachment
          ensure
            ::I18n.locale = initial_language
          end
        end
      end
    end
  end
end
