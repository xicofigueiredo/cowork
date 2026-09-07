class Users::SessionsController < Devise::SessionsController
  def create
    email = params.dig(:user, :email).to_s.strip.downcase
    password = params.dig(:user, :password).to_s
    user = resource_class.find_by(email: email)

    if user && !user.confirmed? && user.valid_password?(password)
      session[:pending_confirmation_email] = user.email
      redirect_to user_confirm_code_path(email: user.email),
                  alert: "Please enter the confirmation code sent to your email before signing in."
      return
    end

    super
  end
end
