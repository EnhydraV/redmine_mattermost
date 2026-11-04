# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class WikiNotificationTest < ActiveSupport::TestCase
  include RedmineMattermost::TestHelper

  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, :enabled_modules,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def test_page_update_is_posted_when_enabled
    content = WikiContent.find 1
    with_mattermost_settings 'post_wiki_updates' => '1' do
      content.text = 'Updated text'
      content.comments = 'Typo *fixed*'
      content.author = User.find 2
      content.save!
    end

    payload = mattermost_payloads.last

    assert_match %r{Wiki \[CookBook documentation\]\(https?://[^)]+/projects/ecookbook/wiki/CookBook_documentation\)}, payload['message']
    assert_includes payload['message'], 'updated by **John Smith**'
    assert_equal 'Typo *fixed*', payload.dig('props', 'attachments', 0, 'text')
  end

  def test_page_update_has_an_actor_message_when_posting_as_actor
    content = WikiContent.find 1
    with_mattermost_settings 'post_wiki_updates' => '1', 'post_as_actor' => '1' do
      content.text = 'Updated by Juliette'
      content.author = User.find 2
      content.save!
    end

    payload = mattermost_payloads.last

    assert_includes payload['message'], 'updated by **John Smith**'
    assert_match(/\) updated\z/, payload['actor_message'])
  end

  def test_page_update_is_not_posted_when_disabled
    content = WikiContent.find 1
    with_mattermost_settings 'post_wiki_updates' => '0' do
      content.text = 'Updated text'
      content.save!
    end

    assert_empty mattermost_deliveries
  end

  def test_page_creation_is_posted_when_enabled
    with_mattermost_settings 'post_wiki' => '1' do
      page = WikiPage.new wiki: Wiki.find(1), title: 'New_page'
      page.content = WikiContent.new text: 'Content', author: User.find(2)
      page.save!
    end

    assert_includes mattermost_payloads.last['message'], 'created by **John Smith**'
  end
end
