# frozen_string_literal: true

Rails.application.routes.draw do
  # Réponses aux notifications, transmises par le plugin Mattermost
  post 'mattermost/replies', to: 'mattermost_replies#create', as: 'mattermost_replies'
  # Images collées dans les notes, affichées dans le corps des notifications
  get 'mattermost/images/:id/:signature/:filename', to: 'mattermost_images#show', as: 'mattermost_image',
                                                    constraints: { id: /\d+/, signature: /\h+/, filename: %r{[^/]+} },
                                                    format: false

  resources :projects, only: [] do
    resource :mattermost_setting, only: %i[update]
  end
end
