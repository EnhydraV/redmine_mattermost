# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class CommonViewsTest < Redmine::IntegrationTest
  include RedmineMattermost::TestHelper

  fixtures :projects,
           :users,
           :email_addresses,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :issues,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers

  def test_view_issue
    log_user 'admin', 'admin'
    get '/issues/1'

    assert_response :success
  end

  def test_plugin_settings_page
    log_user 'admin', 'admin'
    with_mattermost_settings do
      get '/settings/plugin/redmine_mattermost'
    end

    assert_response :success
    assert_select 'input[name=?][value=?]', 'settings[mattermost_url]', 'https://chat.example.com'
    assert_select 'input[type=password][name=?]', 'settings[mattermost_bot_token]'
    assert_select 'input[type=checkbox][name=?][checked=checked]', 'settings[post_updates]'
    assert_select 'select[name=?][multiple=multiple] option[value=?]', 'settings[ignored_attributes][]', 'done_ratio'
  end

  def test_project_settings_tab
    log_user 'admin', 'admin'
    get '/projects/ecookbook/settings/mattermost'

    assert_response :success
    assert_select 'form[action=?]', '/projects/ecookbook/mattermost_setting'
    assert_select 'select[name=?]', 'setting[post_updates]'
    assert_equal 0, MattermostSetting.where(project_id: 1).count, 'displaying the tab must not create a record'
  end
end
