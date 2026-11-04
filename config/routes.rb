# frozen_string_literal: true

Rails.application.routes.draw do
  # Réponses aux notifications, transmises par le plugin Mattermost
  post 'mattermost/replies', to: 'mattermost_replies#create', as: 'mattermost_replies'

  resources :projects, only: [] do
    resource :mattermost_setting, only: %i[update]
  end
end
