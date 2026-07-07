class Users::SessionsController < Devise::SessionsController
  before_action :convert_login_to_email, only: :create

  private

  # Recebe user[login] (CPF ou e-mail), traduz para user[email] que o Devise usa
  def convert_login_to_email
    login = params.dig(:user, :login).to_s.strip
    return if login.blank?

    digits = login.gsub(/\D/, "")
    email = if digits.length == 11
      User.find_by(cpf: digits)&.email
    else
      login
    end

    params[:user][:email] = email || login
  end
end
