class Users::SessionsController < Devise::SessionsController
  # Fluxo padrão do Devise — flash na falha funciona via:
  # - navigational_formats sem :turbo_stream (config/initializers/devise.rb)
  # - data: { turbo: false } no formulário de login
end
