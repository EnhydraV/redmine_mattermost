# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class IgnoredAttributesTest < ActiveSupport::TestCase
  include RedmineMattermost::TestHelper

  fixtures :custom_fields

  def test_key_for_each_kind_of_detail
    assert_equal 'done_ratio', key_for('attr', 'done_ratio')
    assert_equal 'cf_2', key_for('cf', '2')
    assert_equal 'attachment', key_for('attachment', '4')
    assert_equal 'relation', key_for('relation', 'relates')
  end

  def test_reported_details_skip_ignored_custom_fields
    details = [JournalDetail.new(property: 'cf', prop_key: '2'), JournalDetail.new(property: 'attr', prop_key: 'status_id')]

    with_mattermost_settings 'ignored_attributes' => %w[cf_2] do
      assert_equal %w[status_id], RedmineMattermost::IgnoredAttributes.reported(details).map(&:prop_key)
    end
  end

  def test_choices_list_custom_fields_of_issues
    custom_fields = RedmineMattermost::IgnoredAttributes.choices.values.last

    assert_includes custom_fields, [CustomField.find(2).name, 'cf_2']
  end

  private

  def key_for(property, prop_key)
    RedmineMattermost::IgnoredAttributes.key_for JournalDetail.new(property: property, prop_key: prop_key)
  end
end
