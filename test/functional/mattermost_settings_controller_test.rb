# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class MattermostSettingsControllerTest < Redmine::ControllerTest
  tests MattermostSettingsController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules

  def setup
    Role.find(1).add_permission! :manage_mattermost
    @request.session[:user_id] = 2
  end

  def test_update_saves_project_settings
    put :update, params: { project_id: 'ecookbook',
                           setting: { mattermost_team: 'kitchen', mattermost_channel: 'recipes, @juliette', post_wiki: '2' } }

    assert_redirected_to '/projects/ecookbook/settings/mattermost'
    setting = MattermostSetting.find_by project_id: 1

    assert_equal 'kitchen', setting.mattermost_team
    assert_equal 'recipes, @juliette', setting.mattermost_channel
    assert_equal 2, setting.post_wiki
  end

  def test_update_rejects_invalid_channel
    put :update, params: { project_id: 'ecookbook', setting: { mattermost_channel: 'Town Square' } }

    assert_redirected_to '/projects/ecookbook/settings/mattermost'
    assert_not_nil flash[:error]
    assert_nil MattermostSetting.find_by(project_id: 1)
  end

  def test_update_requires_permission
    Role.find(1).remove_permission! :manage_mattermost
    put :update, params: { project_id: 'ecookbook', setting: { mattermost_channel: 'recipes' } }

    assert_response :forbidden
  end
end
