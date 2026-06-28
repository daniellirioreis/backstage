Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users,
             path: "",
             path_names: {
               sign_in: "login",
               sign_out: "logout",
               password: "password"
             }

  get  "evento/selecionar", to: "event_session#select_event", as: :select_event
  post "evento/selecionar", to: "event_session#set_event",    as: :set_event
  delete "evento/limpar",   to: "event_session#clear_event",  as: :clear_event

  resources :roles
  resources :users do
    collection { get :search }
    member do
      get :credential
      get :my_schedule
    end
  end
  resources :events do
    resource :badge_config, only: [:edit, :update]
    member { get :print }
  end
  resources :teams do
    collection do
      get  :search
      get  :import_source_teams    # AJAX: teams de um evento
      get  :import_source_members  # AJAX: membros de uma equipe
    end
    member do
      get  :credentials
      get  :schedule
      post :schedule
      post :import_members
    end
  end
  resources :sectors
  resources :shifts do
    collection do
      get   :print
      get   :timeline
      get   :edit_team
      patch :update_team
    end
  end
  resources :vehicles

  resources :attendances, only: [:index, :destroy] do
    collection do
      get  :scan
      post :check_in
    end
  end

  root "dashboard#index"
end
