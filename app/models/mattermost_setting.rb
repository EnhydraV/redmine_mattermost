# frozen_string_literal: true

class MattermostSetting < ApplicationRecord
  # Nom de canal ou d'équipe tel qu'il apparaît dans l'URL Mattermost, ou @utilisateur
  NAME_FORMAT = /\A[a-z0-9][a-z0-9._-]*\z/
  DESTINATION_FORMAT = /\A(-|@?[a-z0-9][a-z0-9._-]*)\z/

  FLAGS = %w[auto_mentions
             display_watchers
             post_updates
             post_updates_reopened
             new_include_description
             updated_include_description
             post_private_issues
             post_private_notes
             direct_messages
             post_wiki
             post_wiki_updates].freeze

  belongs_to :project

  validates :project_id, uniqueness: true
  validates :mattermost_team, format: { with: NAME_FORMAT, allow_blank: true }, length: { maximum: 255 }
  validates :mattermost_channel, :default_mentions, length: { maximum: 255 }
  validates(*FLAGS, inclusion: { in: [RedmineMattermost::ProjectSettings::INHERIT,
                                      RedmineMattermost::ProjectSettings::DISABLED,
                                      RedmineMattermost::ProjectSettings::ENABLED] })
  validate :validate_channels

  private

  def validate_channels
    return if mattermost_channel.blank?

    invalid = mattermost_channel.split(',').map(&:strip).compact_blank.grep_v(DESTINATION_FORMAT)
    errors.add :mattermost_channel, :invalid if invalid.any?
  end
end
