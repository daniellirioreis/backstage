class Users::PasswordsController < Devise::PasswordsController
  def create
    super
  rescue => e
    Rails.logger.error "[SMTP ERROR] #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise
  end
end
