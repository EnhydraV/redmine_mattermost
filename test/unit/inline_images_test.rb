# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class InlineImagesTest < ActiveSupport::TestCase
  InlineImages = RedmineMattermost::InlineImages

  fixtures :projects, :issues, :attachments

  def setup
    set_fixtures_attachments_directory
  end

  def teardown
    set_tmp_attachments_directory
  end

  def test_pasted_html_image_is_removed_with_its_line_break
    text, images = extract "C'est reparti :rocket:\n<img style=\"width: 1090px;\" src=\"picture.jpg\"><br>"

    assert_equal "C'est reparti :rocket:", text
    assert_equal [10], images.map(&:id)
  end

  def test_markdown_and_textile_images_are_removed
    text, images = extract 'Avant ![capture](picture.jpg "Roméo") et !{width:50%}picture.jpg(alt)! après'

    assert_equal 'Avant  et  après', text
    assert_equal [10], images.map(&:id)
  end

  def test_unknown_image_stays_in_the_text
    text, images = extract '<img src="missing.png"> ![](https://example.com/victor.png)'

    assert_equal '<img src="missing.png"> ![](https://example.com/victor.png)', text
    assert_empty images
  end

  def test_url_encoded_name_is_found_like_redmine_does
    attachments = Issue.find(14).attachments.to_a
    _text, images = InlineImages.extract '![](test%E3%83%86%E3%82%B9%E3%83%88.png)', attachments

    assert_equal [Attachment.latest_attach(attachments, 'testテスト.png')], images
  end

  def test_read_returns_the_file_in_base64
    data = InlineImages.read 16

    assert_equal File.binread(Attachment.find(16).diskfile), Base64.strict_decode64(data)
  end

  def test_read_skips_files_over_the_size_limit
    Attachment.any_instance.stubs(:filesize).returns(InlineImages::MAX_FILE_SIZE + 1)

    assert_nil InlineImages.read(16)
  end

  private

  def extract(text)
    InlineImages.extract text, Issue.find(2).attachments.to_a
  end
end
