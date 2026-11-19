# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class IssueNotificationTest < ActiveSupport::TestCase
  include RedmineMattermost::TestHelper

  fixtures :projects, :users, :email_addresses, :user_preferences, :members, :member_roles, :roles,
           :trackers, :projects_trackers, :enabled_modules,
           :issue_statuses, :issue_categories, :workflows, :enumerations,
           :issues, :journals, :journal_details, :watchers,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :repositories, :changesets

  def setup
    User.current = User.find 1
  end

  def teardown
    User.current = nil
  end

  def test_created_issue_is_posted_with_markdown_links
    issue = nil
    with_mattermost_settings do
      issue = Issue.create! project_id: 1, tracker_id: 1, author_id: 2,
                            subject: 'Recipe *bold*', description: 'Some _text_'
    end

    assert_equal 1, mattermost_deliveries.size
    target, payload = mattermost_deliveries.first

    assert_equal({ 'team' => 'dev', 'channel' => 'redmine' }, target)
    assert_match %r{\A\[eCookbook\]\(https?://[^)]+/projects/ecookbook\) - }, payload['message']
    assert_match %r{\[Bug #\d+: Recipe \\\*bold\\\*\]\(https?://[^)]+/issues/#{issue.id}\)}, payload['message']
    assert_includes payload['message'], 'created by **John Smith**'
    assert_equal 'Some _text_', payload.dig('props', 'attachments', 0, 'text')
    assert_equal(%w[Status Priority], attachment_fields(payload).map { |field| field['title'] })
  end

  def test_nothing_is_posted_without_bot_token
    with_mattermost_settings 'mattermost_bot_token' => '' do
      Issue.create! project_id: 1, tracker_id: 1, author_id: 2, subject: 'No token'
    end

    assert_empty mattermost_deliveries
  end

  def test_update_posts_changes_and_notes
    issue = Issue.find 1
    with_mattermost_settings do
      issue.init_journal User.find(2), 'Looks *good*'
      issue.status_id = 2
      issue.save!
    end

    payload = mattermost_payloads.last

    assert_includes payload['message'], "#change-#{issue.journals.last.id})"
    assert_includes payload['message'], 'updated by **John Smith**'
    fields = attachment_fields payload

    assert_equal 'Assigned', fields.detect { |field| field['title'] == 'Status' }['value']
    assert_equal({ 'title' => 'Comment', 'value' => 'Looks *good*', 'short' => false },
                 fields.detect { |field| field['title'] == 'Comment' })
  end

  def test_update_without_post_updates_is_not_posted
    issue = Issue.find 1
    with_mattermost_settings 'post_updates' => '0' do
      issue.init_journal User.find(2), 'A note'
      issue.save!
    end

    assert_empty mattermost_deliveries
  end

  def test_private_notes_are_skipped_unless_enabled
    issue = Issue.find 1
    with_mattermost_settings 'post_private_notes' => '0' do
      issue.init_journal User.find(2), 'Secret'
      issue.current_journal.private_notes = true
      issue.save!
    end

    assert_empty mattermost_deliveries
  end

  def test_reopened_only_ignores_other_updates
    with_mattermost_settings 'post_updates_reopened' => '1' do
      issue = Issue.find 1
      issue.init_journal User.find(2), 'Just a note'
      issue.save!

      assert_empty mattermost_deliveries

      Issue.find(1).update_columns status_id: 5
      issue = Issue.find 1
      issue.init_journal User.find(2), 'Reopening'
      issue.status_id = 2
      issue.save!
    end

    assert_equal 1, mattermost_payloads.size
    assert_includes attachment_fields(mattermost_payloads.first).pluck('value'), 'Assigned'
  end

  def test_mentions_come_from_default_list_and_notes
    issue = Issue.find 1
    with_mattermost_settings 'auto_mentions' => '1', 'default_mentions' => '@juliette' do
      issue.init_journal User.find(2), 'Hello @dlopper'
      issue.save!
    end

    assert_includes mattermost_payloads.last['message'], "\nTo: @juliette, @dlopper"
  end

  def test_actor_is_never_mentioned
    issue = Issue.find 1
    with_mattermost_settings 'auto_mentions' => '1', 'default_mentions' => '@JSmith, @juliette' do
      issue.init_journal User.find(2), 'Note to self @jsmith'
      issue.save!
    end

    message = mattermost_payloads.last['message']

    assert_includes message, "\nTo: @juliette"
    assert_not_includes message.downcase, '@jsmith'
  end

  def test_notes_mentions_are_ignored_without_auto_mentions
    issue = Issue.find 1
    with_mattermost_settings 'auto_mentions' => '0' do
      issue.init_journal User.find(2), 'Hello @dlopper'
      issue.save!
    end

    assert_not_includes mattermost_payloads.last['message'], '@dlopper'
  end

  def test_mentioned_users_are_sent_for_conversion
    issue = Issue.find 1
    with_mattermost_settings 'auto_mentions' => '1' do
      issue.init_journal User.find(2), 'Hello @dlopper'
      issue.save!
    end

    assert_equal [{ 'login' => 'dlopper', 'email' => 'dlopper@somenet.foo' }], mattermost_payloads.last['mention_users']
  end

  def test_direct_message_targets_carry_the_email
    issue = Issue.find 1
    with_mattermost_settings 'direct_messages' => '1' do
      issue.init_journal User.find(1), 'Ping'
      issue.save!
    end

    assert_includes mattermost_deliveries.map(&:first), { 'username' => 'jsmith', 'email' => 'jsmith@somenet.foo' }
  end

  def test_direct_messages_target_notified_users_except_actor
    issue = Issue.find 1
    with_mattermost_settings 'direct_messages' => '1' do
      issue.init_journal User.find(1), 'Ping'
      issue.save!
    end

    usernames = mattermost_deliveries.filter_map { |target, _payload| target['username'] }

    assert_includes usernames, 'jsmith'
    assert_not_includes usernames, 'admin'
  end

  def test_commit_keyword_update_includes_revision_link
    issue = Issue.find 1
    with_mattermost_settings do
      issue.init_journal User.find(3), 'Applied in changeset r1.'
      issue.mattermost_changeset = Changeset.find 100
      issue.status_id = 2
      issue.save!
    end

    field = attachment_fields(mattermost_payloads.last).detect { |f| f['title'] == 'Revision' }

    assert_match %r{\A\[1\]\(https?://[^)]+/revisions/1\)\z}, field['value']
    assert_not_includes mattermost_payloads.last.to_json, 'My very first commit'
    assert_nil issue.mattermost_changeset
  end

  def test_update_touching_only_ignored_attributes_is_not_posted
    issue = Issue.find 1
    with_mattermost_settings 'ignored_attributes' => %w[done_ratio] do
      issue.init_journal User.find(2)
      issue.done_ratio = 30
      issue.save!
    end

    assert_empty mattermost_deliveries
  end

  def test_ignored_attributes_are_left_out_of_the_message
    issue = Issue.find 1
    with_mattermost_settings 'ignored_attributes' => ['', 'done_ratio'] do
      issue.init_journal User.find(2)
      issue.done_ratio = 30
      issue.status_id = 2
      issue.save!
    end

    assert_equal %w[Status], attachment_fields(mattermost_payloads.last).pluck('title')
  end

  def test_note_is_posted_when_only_ignored_attributes_change
    issue = Issue.find 1
    with_mattermost_settings 'ignored_attributes' => %w[done_ratio] do
      issue.init_journal User.find(2), 'Halfway there'
      issue.done_ratio = 50
      issue.save!
    end

    assert_equal %w[Comment], attachment_fields(mattermost_payloads.last).pluck('title')
  end

  def test_new_subtask_is_not_posted_on_the_parent_when_ignored
    child = Issue.find 2
    with_mattermost_settings 'ignored_attributes' => %w[child_id] do
      child.init_journal User.find(2)
      child.parent_issue_id = 1
      child.save!
    end

    assert_equal([2], mattermost_payloads.map { |payload| payload.dig('props', 'redmine_issue_id') })
  end

  def test_pasted_image_leaves_the_note_and_goes_with_the_post
    issue = Issue.find 2
    with_mattermost_settings do
      issue.init_journal User.find(2), "C'est reparti\n<img style=\"width: 1090px;\" src=\"picture.jpg\"><br>"
      issue.save!
    end

    payload = mattermost_payloads.last

    assert_equal "C'est reparti", attachment_fields(payload).detect { |field| field['title'] == 'Comment' }['value']
    assert_equal([{ 'id' => 10, 'name' => 'picture.jpg' }], payload['images'].map { |image| image.except 'link' })
    assert_match %r{\A\[picture\.jpg\]\(https?://[^)]+/attachments/10/picture\.jpg\)\z}, payload['images'].first['link']
  end

  def test_note_made_of_an_image_only_has_no_comment_field
    issue = Issue.find 2
    with_mattermost_settings do
      issue.init_journal User.find(2), '![](picture.jpg)'
      issue.save!
    end

    payload = mattermost_payloads.last

    assert_not_includes attachment_fields(payload).pluck('title'), 'Comment'
    assert_equal 1, payload['images'].size
  end

  def test_ignored_description_is_not_sent_as_text
    issue = Issue.find 1
    with_mattermost_settings 'ignored_attributes' => %w[description] do
      issue.init_journal User.find(2), 'New wording'
      issue.description = 'Rewritten by Oscar'
      issue.save!
    end

    assert_nil mattermost_payloads.last.dig('props', 'attachments', 0, 'text')
  end

  def test_private_issue_is_skipped_unless_enabled
    with_mattermost_settings 'post_private_issues' => '0' do
      Issue.create! project_id: 1, tracker_id: 1, author_id: 2, subject: 'Hidden', is_private: true
    end

    assert_empty mattermost_deliveries
  end

  def test_actor_identity_is_sent_when_posting_as_actor
    issue = Issue.find 1
    with_mattermost_settings 'post_as_actor' => '1' do
      issue.init_journal User.find(2), 'As myself'
      issue.save!
    end

    _target, _payload, actor = mattermost_deliveries.last

    assert_equal({ 'username' => 'jsmith', 'email' => 'jsmith@somenet.foo' }, actor)
  end

  def test_actor_message_leaves_out_the_author
    issue = Issue.find 1
    with_mattermost_settings 'post_as_actor' => '1' do
      issue.init_journal User.find(2), 'As myself'
      issue.save!
    end

    payload = mattermost_payloads.last

    assert_includes payload['message'], 'updated by **John Smith**'
    assert_match %r{ - Issue \[[^\]]+\]\(https?://[^)]+#change-\d+\) updated\z}, payload['actor_message']
  end

  def test_no_actor_message_without_posting_as_actor
    issue = Issue.find 1
    with_mattermost_settings do
      issue.init_journal User.find(2), 'As the bot'
      issue.save!
    end

    assert_not mattermost_payloads.last.key?('actor_message')
  end

  def test_no_actor_identity_by_default
    issue = Issue.find 1
    with_mattermost_settings do
      issue.init_journal User.find(2), 'As the bot'
      issue.save!
    end

    assert_nil mattermost_deliveries.last.third
  end
end
