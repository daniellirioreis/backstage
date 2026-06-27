class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def pundit_user
    current_user
  end

  def user_not_authorized
    flash[:alert] = t("errors.not_authorized")
    redirect_back(fallback_location: root_path)
  end
end
