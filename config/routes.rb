# frozen_string_literal: true

Rails.application.routes.draw do
  resources :projects, only: [] do
    resource :mattermost_setting, only: %i[update]
  end
end
