# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class I18nTest < ActiveSupport::TestCase
  include Redmine::I18n

  def setup
    User.current = nil
  end

  def teardown
    set_language_if_valid 'en'
  end

  def test_valid_languages
    assert_kind_of Array, valid_languages
    assert_kind_of Symbol, valid_languages.first
  end

  def test_locales_validness
    lang_files_count = Rails.root.glob('plugins/redmine_mattermost/config/locales/*.yml').size

    assert_equal 7, lang_files_count
    valid_languages.each do |lang|
      assert set_language_if_valid(lang)
      case lang.to_s
      when 'en'

        assert_equal 'Bot access token', l(:label_settings_mattermost_bot_token)
      when 'de', 'fr', 'ja', 'ko', 'nl', 'pt-BR'

        assert_not l(:label_settings_mattermost_bot_token) == 'Bot access token', lang
      end
    end

    set_language_if_valid 'en'
  end
end
