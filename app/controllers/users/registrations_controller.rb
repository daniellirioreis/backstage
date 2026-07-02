class Users::RegistrationsController < Devise::RegistrationsController
  def new
    redirect_to new_user_session_path, alert: "O acesso ao sistema é somente por convite."
  end

  def create
    redirect_to new_user_session_path, alert: "O acesso ao sistema é somente por convite."
  end
end
