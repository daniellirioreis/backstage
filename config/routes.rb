Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users,
             path: "",
             path_names: {
               sign_in: "login",
               sign_out: "logout",
               password: "password"
             },
             controllers: { registrations: "users/registrations", sessions: "users/sessions", passwords: "users/passwords" }

  # Convites
  resources :invitations, only: [:index, :new, :create]
  get  "/convite/:token", to: "invitations#accept",  as: :accept_invitation
  post "/convite/:token", to: "invitations#confirm", as: :confirm_invitation

  # Onboarding wizard
  get  "onboarding/empresa",      to: "onboarding#empresa",     as: :onboarding_empresa
  post "onboarding/empresa",      to: "onboarding#save_empresa"
  get  "onboarding/plano",        to: "onboarding#plano",       as: :onboarding_plano
  post "onboarding/plano",        to: "onboarding#save_plano"
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
      patch :set_plan
    end
  end
  resources :plans
  resources :roles
  resources :users do
    collection { get :search }
    member do
      get :credential
      get :my_schedule
    end
  end
  # Catálogo de funções (independente de evento)
  resources :event_functions, only: [:index, :new, :create, :edit, :update, :destroy]

  resources :events do
    resource  :badge_config, only: [:edit, :update] do
      get :preview, on: :member
    end
    resources :event_functions, only: [:index, :create, :update, :destroy] do
      collection do
        post :add_from_catalog
      end
    end
    resource :setup, only: [], controller: 'events/setup' do
      get  :sectors
      post :sectors,        action: :save_sectors
      get  :teams
      post :teams,          action: :save_teams
      get  :schedules
      post :finish
      get  :import_source_events
      get  :import_source_sector_teams
      post :import_teams
      post :quick_add_collaborator
    end
    collection do
      get :event_type_stats
    end
    member do
      get   :print
      get   :budget
      get   :credentials
      patch :transition
      patch :revert
    end
  end
  resources :teams do
    collection do
      get  :search
      get  :coordinator
      get  :import_source_teams    # AJAX: teams de um evento
      get  :import_source_members  # AJAX: membros de uma equipe
      get  :search_available       # AJAX: usuários disponíveis para adicionar
    end
    member do
      get   :panel
      get   :credentials
      get   :schedule
      post  :schedule
      post  :import_members
      patch :set_function
      post  :quick_add_member
    end
  end
  resources :sectors do
    collection do
      get :sector_type_stats
    end
    resources :sector_functions, only: [:create, :update, :destroy]
  end
  resources :shifts do
    collection do
      get    :print
      get    :timeline
      get    :edit_team
      patch  :update_team
      delete :delete_team
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
      patch  :manual_checkout
    end
  end

  get  "reports/closing",                 to: "reports/closing#index",            as: :reports_closing
  get  "reports/closing/print",           to: "reports/closing#print",            as: :reports_closing_print
  get  "reports/closing/export",          to: "reports/closing#export",           as: :reports_closing_export
  post "reports/closing/finalize",        to: "reports/closing#finalize",         as: :reports_closing_finalize
  post "reports/closing/reopen",          to: "reports/closing#reopen",           as: :reports_closing_reopen
  get  "reports/attendance",              to: "reports/attendance#index",          as: :reports_attendance
  get  "reports/absences",                to: "reports/absences#index",            as: :reports_absences
  get  "reports/hours_worked",            to: "reports/hours_worked#index",        as: :reports_hours_worked
  get  "reports/sector_summary",          to: "reports/sector_summary#index",      as: :reports_sector_summary

  namespace :reports do
    resources :payments, only: [:create, :destroy] do
      member do
        get  :receipt
        get  :receipt_pdf, format: :pdf
      end
    end
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  root "dashboard#index"
end
