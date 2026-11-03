# frozen_string_literal: true

class MattermostSettingsController < ApplicationController
  before_action :find_project_by_project_id
  before_action :authorize

  def update
    setting = MattermostSetting.find_or_initialize_by project_id: @project.id
    if setting.update allowed_params
      flash[:notice] = l :notice_successful_update
    else
      flash[:error] = setting.errors.full_messages.join "\n"
    end
    redirect_to settings_project_path(@project, tab: 'mattermost')
  end

  private

  def allowed_params
    params.require(:setting).permit :mattermost_team,
                                    :mattermost_channel,
                                    :default_mentions,
                                    *MattermostSetting::FLAGS
  end
end
