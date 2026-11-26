# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class InlineImagesTest < ActiveSupport::TestCase
  InlineImages = RedmineMattermost::InlineImages
  SIGNED_URL = %r{http://[^)\s]+/mattermost/images/10/\h{32}/picture\.jpg}

  fixtures :projects, :issues, :attachments

  def test_pasted_html_image_becomes_a_markdown_image_in_place
    text = embed "C'est reparti :rocket:\n<img style=\"width: 1090px;\" src=\"picture.jpg\"><br>\nSuite"

    assert_match(/\AC'est reparti :rocket:\n!\[picture\.jpg\]\(#{SIGNED_URL}\)\nSuite\z/o, text)
  end

  def test_markdown_and_textile_images_are_signed
    text = embed 'Avant ![capture](picture.jpg "Roméo") et !{width:50%}picture.jpg(alt)! après'

    assert_match(/\AAvant !\[picture\.jpg\]\(#{SIGNED_URL}\) et !\[picture\.jpg\]\(#{SIGNED_URL}\) après\z/o, text)
  end

  def test_unknown_image_stays_in_the_text
    text = '<img src="missing.png"> ![](https://example.com/victor.png)'

    assert_equal text, embed(text)
  end

  def test_url_encoded_name_is_found_like_redmine_does
    attachments = Issue.find(14).attachments.to_a
    found = Attachment.latest_attach attachments, 'testテスト.png'

    assert_includes InlineImages.embed('![](test%E3%83%86%E3%82%B9%E3%83%88.png)', attachments),
                    "/mattermost/images/#{found.id}/"
  end

  def test_signature_depends_on_the_attachment
    picture = Attachment.find 10

    assert InlineImages.valid_signature?(picture, InlineImages.signature(picture))
    assert_not InlineImages.valid_signature?(picture, InlineImages.signature(Attachment.find(16)))
    assert_not InlineImages.valid_signature?(picture, '')
  end

  def test_svg_is_never_served
    attachment = Attachment.new filename: 'oscar.svg', content_type: 'image/svg+xml'

    assert_not InlineImages.servable?(attachment)
  end

  private

  def embed(text)
    InlineImages.embed text, Issue.find(2).attachments.to_a
  end
end
