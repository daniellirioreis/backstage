class Users::SessionsController < Devise::SessionsController
  # Ao falhar o login, re-renderiza o formulário com o flash inline
  # em vez de depender do redirect + flash do Devise (problemático com Turbo)
  def create
    self.resource = warden.authenticate(auth_options)

    if resource
      set_flash_message!(:notice, :signed_in)
      resource.remember_me = Devise::TRUE_VALUES.include?(sign_in_params[:remember_me])
      sign_in(resource_name, resource, force: true)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      self.resource = resource_class.new(sign_in_params)
      clean_up_passwords(self.resource)
      flash.now[:alert] = I18n.t("devise.failure.invalid", authentication_keys: "e-mail")
      render :new, status: :unprocessable_entity
    end
  end
end
