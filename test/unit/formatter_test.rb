# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class FormatterTest < ActiveSupport::TestCase
  def test_escape_neutralizes_markdown
    assert_equal 'a\\*b\\* \\_c\\_ \\[d\\] \\`e\\`', RedmineMattermost::Formatter.escape('a*b* _c_ [d] `e`')
  end

  def test_link_escapes_label_and_parentheses_in_url
    assert_equal '[file\\_(1).pdf](https://x.test/a/file%281%29.pdf)',
                 RedmineMattermost::Formatter.link('https://x.test/a/file(1).pdf', 'file_(1).pdf')
  end

  def test_field_replaces_blank_value_with_dash
    assert_equal({ 'title' => 'Status', 'value' => '-', 'short' => true },
                 RedmineMattermost::Formatter.field('Status', ''))
  end

  def test_post_without_attachment
    assert_equal({ 'message' => 'Hello' }, RedmineMattermost::Formatter.post('Hello'))
  end
end
