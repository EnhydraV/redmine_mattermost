# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class JournalFieldTest < ActiveSupport::TestCase
  include Redmine::I18n

  fixtures :projects, :users, :trackers, :issue_statuses, :enumerations, :issues,
           :journals, :journal_details, :custom_fields, :attachments

  def setup
    set_language_if_valid 'en'
  end

  def test_status_change_shows_new_status_name
    detail = JournalDetail.new property: 'attr', prop_key: 'status_id', old_value: '1', value: '2'

    assert_equal({ 'title' => 'Status', 'value' => 'Assigned', 'short' => true }, RedmineMattermost::JournalField.for(detail))
  end

  def test_subject_is_a_long_field
    detail = JournalDetail.new property: 'attr', prop_key: 'subject', value: 'New *subject*'

    assert_equal({ 'title' => 'Subject', 'value' => 'New \\*subject\\*', 'short' => false },
                 RedmineMattermost::JournalField.for(detail))
  end

  def test_description_is_left_out
    detail = JournalDetail.new property: 'attr', prop_key: 'description', value: 'Text'

    assert_nil RedmineMattermost::JournalField.for(detail)
  end

  def test_parent_is_a_link_to_the_issue
    detail = JournalDetail.new property: 'attr', prop_key: 'parent_id', value: '2'

    assert_match %r{\A\[Feature request #2: .+\]\(https?://[^)]+/issues/2\)\z}, RedmineMattermost::JournalField.for(detail)['value']
  end

  def test_deleted_custom_field_is_left_out
    detail = JournalDetail.new property: 'cf', prop_key: '999999', value: 'x'

    assert_nil RedmineMattermost::JournalField.for(detail)
  end

  def test_custom_field_hidden_to_some_roles_is_left_out
    custom_field = IssueCustomField.create! name: 'Restricted', field_format: 'string', visible: false, role_ids: [1]
    detail = JournalDetail.new property: 'cf', prop_key: custom_field.id.to_s, value: 'secret'

    assert_nil RedmineMattermost::JournalField.for(detail)
  end

  def test_public_custom_field_is_shown
    custom_field = IssueCustomField.create! name: 'Public', field_format: 'string', visible: true
    detail = JournalDetail.new property: 'cf', prop_key: custom_field.id.to_s, value: 'Charlie'

    assert_equal({ 'title' => 'Public', 'value' => 'Charlie', 'short' => true }, RedmineMattermost::JournalField.for(detail))
  end

  def test_removed_attachment_is_struck_through
    detail = JournalDetail.new property: 'attachment', prop_key: '999999', old_value: 'old_file.txt'

    assert_equal '~~old\\_file.txt~~', RedmineMattermost::JournalField.for(detail)['value']
  end
end
