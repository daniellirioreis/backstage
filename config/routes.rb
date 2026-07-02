Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users,
             path: "",
             path_names: {
               sign_in: "login",
               sign_out: "logout",
               password: "password"
             },
             controllers: { registrations: "users/registrations" }

  # Convites
  resources :invitations, only: [:index, :new, :create]
  get  "/convite/:token", to: "invitations#accept",  as: :accept_invitation
  post "/convite/:token", to: "invitations#confirm", as: :confirm_invitation

  # Onboarding wizard
  get  "onboarding/empresa",      to: "onboarding#empresa",     as: :onboarding_empresa
  post "onboarding/empresa",      to: "onboarding#save_empresa"
  get  "onboarding/evento",       to: "onboarding#evento",      as: :onboarding_evento
  post "onboarding/evento",       to: "onboarding#save_evento"
  post "onboarding/evento/pular", to: "onboarding#skip_evento", as: :onboarding_skip_evento
  get  "onboarding/concluido",    to: "onboarding#done",        as: :onboarding_done

  get  "events/select", to: "event_session#select_event", as: :select_event
  post "events/select", to: "event_session#set_event",    as: :set_event
  delete "events/clear", to: "event_session#clear_event", as: :clear_event

  resources :companies do
    member do
      post :add_user
      patch :update_user_role
      delete :remove_user
    end
  end
  resources :roles
  resources :users do
    collection { get :search }
    member do
      get :credential
      get :my_schedule
    end
  end
  resources :events do
    resource  :badge_config, only: [:edit, :update]
    resources :event_functions, only: [:create, :update, :destroy]
    member { get :print }
  end
  resources :teams do
    collection do
      get  :search
      get  :import_source_teams    # AJAX: teams de um evento
      get  :import_source_members  # AJAX: membros de uma equipe
    end
    member do
      get   :credentials
      get   :schedule
      post  :schedule
      post  :import_members
      patch :set_function
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
      post :check_out
    end
    member do
      delete :cancel_checkout
    end
  end

  get "reports/closing",       to: "reports/closing#index", as: :reports_closing
  get "reports/closing/print", to: "reports/closing#print", as: :reports_closing_print

  root "dashboard#index"
end
