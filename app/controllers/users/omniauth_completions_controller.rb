class Users::OmniauthCompletionsController < ApplicationController
  before_action :require_pending_omniauth

  def show
    @auth = pending_omniauth
    @user = User.new(
      email: @auth["email"],
      first_name: @auth["first_name"],
      last_name: @auth["last_name"]
    )
  end

  def create
    @auth = pending_omniauth
    attrs = params.fetch(:user, {}).permit(:first_name, :last_name, :referral_source, :referral_source_other)

    user = User.new(
      provider: @auth["provider"],
      uid: @auth["uid"],
      email: @auth["email"],
      first_name: attrs[:first_name].presence || @auth["first_name"],
      last_name: attrs[:last_name].presence || @auth["last_name"],
      referral_source: attrs[:referral_source],
      referral_source_other: attrs[:referral_source_other],
      password: Devise.friendly_token[0, 20]
    )
    user.skip_confirmation!

    if user.save
      clear_pending_omniauth
      UserMailer.welcome(user).deliver_now
      sign_in(user)
      redirect_to root_path, notice: "Welcome! Your account is ready."
    else
      @user = user
      render :show, status: :unprocessable_content
    end
  end

  private

  def pending_omniauth
    session["omniauth.google"]
  end

  def require_pending_omniauth
    return if pending_omniauth.present?

    redirect_to new_user_registration_path, alert: "Please continue with Google to finish signing up."
  end

  def clear_pending_omniauth
    session.delete("omniauth.google")
  end
end
