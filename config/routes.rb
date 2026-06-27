Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users,
             path: "",
             path_names: {
               sign_in: "login",
               sign_out: "logout",
               password: "password"
             }

  resources :roles
  resources :users
  resources :events
  resources :teams
  resources :sectors
  resources :shifts
  resources :vehicles

  root "dashboard#index"
end
