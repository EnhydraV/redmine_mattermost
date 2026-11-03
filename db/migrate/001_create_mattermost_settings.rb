# frozen_string_literal: true

class CreateMattermostSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :mattermost_settings do |t|
      t.references :project, null: false, index: { unique: true }
      t.string :mattermost_team
      t.string :mattermost_channel
      t.string :default_mentions
      t.integer :auto_mentions, default: 0, null: false
      t.integer :display_watchers, default: 0, null: false
      t.integer :post_updates, default: 0, null: false
      t.integer :post_updates_reopened, default: 0, null: false
      t.integer :new_include_description, default: 0, null: false
      t.integer :updated_include_description, default: 0, null: false
      t.integer :post_private_issues, default: 0, null: false
      t.integer :post_private_notes, default: 0, null: false
      t.integer :direct_messages, default: 0, null: false
      t.integer :post_wiki, default: 0, null: false
      t.integer :post_wiki_updates, default: 0, null: false
    end
  end
end
