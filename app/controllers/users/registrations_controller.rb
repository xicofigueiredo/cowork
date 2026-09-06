class Users::RegistrationsController < Devise::RegistrationsController
  protected

  def after_inactive_sign_up_path_for(resource)
    user_confirmation_path(email: resource.email)
  end
end
