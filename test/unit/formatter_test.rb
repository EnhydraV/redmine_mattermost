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

  def test_replace_mentions_rewrites_every_string_of_the_payload
    payload = { 'message' => 'To: @charlie@example.com, @juliette',
                'props' => { 'attachments' => [{ 'fields' => [{ 'value' => 'Ask @Charlie@example.com.' }] }] } }

    result = RedmineMattermost::Formatter.replace_mentions payload, 'charlie@example.com' => 'charlie'

    assert_equal 'To: @charlie, @juliette', result['message']
    assert_equal 'Ask @charlie.', result.dig('props', 'attachments', 0, 'fields', 0, 'value')
  end

  def test_replace_mentions_leaves_longer_logins_alone
    text = 'Mail @charlie@example.com.au or oscar@charlie@example.com'

    assert_equal text, RedmineMattermost::Formatter.replace_mentions(text, 'charlie@example.com' => 'charlie')
  end

  def test_field_replaces_blank_value_with_dash
    assert_equal({ 'title' => 'Status', 'value' => '-', 'short' => true },
                 RedmineMattermost::Formatter.field('Status', ''))
  end

  def test_post_without_attachment
    assert_equal({ 'message' => 'Hello' }, RedmineMattermost::Formatter.post('Hello'))
  end
end
