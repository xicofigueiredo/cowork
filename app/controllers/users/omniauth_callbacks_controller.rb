class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)

    if user&.persisted?
      sign_in_and_redirect user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      return
    end

    session["omniauth.google"] = {
      "provider" => auth.provider,
      "uid" => auth.uid,
      "email" => auth.info.email,
      "first_name" => auth.info.first_name.presence || auth.info.name.to_s.split(/\s+/, 2).first,
      "last_name" => auth.info.last_name.presence || auth.info.name.to_s.split(/\s+/, 2).last
    }

    redirect_to users_omniauth_complete_path
  end

  def failure
    redirect_to new_user_session_path, alert: "Google sign-in was cancelled or failed. Please try again."
  end
end
