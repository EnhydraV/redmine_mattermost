# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class MattermostImagesTest < Redmine::IntegrationTest
  fixtures :projects, :users, :issues, :attachments

  def setup
    set_fixtures_attachments_directory
  end

  def teardown
    set_tmp_attachments_directory
  end

  def test_signed_url_serves_the_image_without_session
    attachment = Attachment.find 16
    get image_path(attachment)

    assert_response :success
    assert_equal 'image/png', response.media_type
    assert_equal File.binread(attachment.diskfile), response.body
    assert_includes response.headers['Content-Disposition'], 'inline'
    assert_equal "default-src 'none'; sandbox", response.headers['Content-Security-Policy']
  end

  def test_wrong_signature_is_not_found
    get "/mattermost/images/16/#{'0' * 32}/testfile.png"

    assert_response :not_found
  end

  def test_signature_of_another_attachment_is_not_found
    get image_path(Attachment.find(16)).sub('/16/', '/17/')

    assert_response :not_found
  end

  def test_non_image_attachment_is_not_found
    get image_path(Attachment.find(1))

    assert_response :not_found
  end

  private

  def image_path(attachment)
    signature = RedmineMattermost::InlineImages.signature attachment
    "/mattermost/images/#{attachment.id}/#{signature}/#{ERB::Util.url_encode attachment.filename}"
  end
end
