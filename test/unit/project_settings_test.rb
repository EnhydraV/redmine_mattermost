# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ProjectSettingsTest < ActiveSupport::TestCase
  include RedmineMattermost::TestHelper

  fixtures :projects

  def setup
    @parent = Project.find 1
    @child = Project.find 3
  end

  def test_text_falls_back_to_global_setting
    with_mattermost_settings do
      assert_equal 'redmine', RedmineMattermost::ProjectSettings.text(@child, :mattermost_channel)
    end
  end

  def test_text_is_inherited_from_parent_project
    set_project_setting @parent, mattermost_channel: 'cookbook'

    with_mattermost_settings do
      assert_equal 'cookbook', RedmineMattermost::ProjectSettings.text(@child.reload, :mattermost_channel)
    end
  end

  def test_project_text_overrides_parent
    set_project_setting @parent, mattermost_channel: 'cookbook'
    set_project_setting @child, mattermost_channel: 'subproject'

    with_mattermost_settings do
      assert_equal 'subproject', RedmineMattermost::ProjectSettings.text(@child, :mattermost_channel)
      assert_equal 'cookbook', RedmineMattermost::ProjectSettings.inherited_text(@child, :mattermost_channel)
    end
  end

  def test_flags_follow_project_then_parent_then_global
    with_mattermost_settings 'post_wiki' => '0' do
      assert_not RedmineMattermost::ProjectSettings.enabled?(@child, :post_wiki)

      set_project_setting @parent, post_wiki: RedmineMattermost::ProjectSettings::ENABLED

      assert RedmineMattermost::ProjectSettings.enabled?(@child.reload, :post_wiki)

      set_project_setting @child, post_wiki: RedmineMattermost::ProjectSettings::DISABLED

      assert_not RedmineMattermost::ProjectSettings.enabled?(@child, :post_wiki)
      assert RedmineMattermost::ProjectSettings.inherited_enabled?(@child, :post_wiki)
    end
  end

  def test_channels_are_split_and_deduplicated
    with_mattermost_settings 'mattermost_channel' => ' town-square, redmine ,town-square,, @juliette' do
      assert_equal %w[town-square redmine @juliette], RedmineMattermost::ProjectSettings.channels(@parent)
    end
  end

  def test_dash_disables_channels_for_a_project
    set_project_setting @child, mattermost_channel: '-'

    with_mattermost_settings do
      assert_empty RedmineMattermost::ProjectSettings.channels(@child)
      assert_equal %w[redmine], RedmineMattermost::ProjectSettings.channels(@parent)
    end
  end
end
