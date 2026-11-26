# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class RoutingTest < Redmine::RoutingTest
  def test_mattermost_routes
    should_route 'GET /projects/1/settings/mattermost' => 'projects#settings', id: '1', tab: 'mattermost'
    should_route 'PUT /projects/1/mattermost_setting' => 'mattermost_settings#update', project_id: '1'
    should_route 'POST /mattermost/replies' => 'mattermost_replies#create'
    should_route 'GET /mattermost/images/10/0123abcd/picture.jpg' => 'mattermost_images#show',
                 id: '10', signature: '0123abcd', filename: 'picture.jpg'
  end
end
