class Users::ConfirmationsController < Devise::ConfirmationsController
  def show
    if params[:confirmation_token].present?
      super
    else
      self.resource = resource_class.new
      resource.email = params[:email] if params[:email].present?
      render :show
    end
  end

  def confirm_code
    email = params.dig(:user, :email).to_s.strip.downcase
    code = params.dig(:user, :confirmation_token).to_s.strip

    self.resource = resource_class.find_by(email: email)

    if resource.nil?
      self.resource = resource_class.new(email: email)
      resource.errors.add(:email, :not_found)
      render :show, status: :unprocessable_entity
      return
    end

    if resource.confirmed?
      set_flash_message!(:notice, :already_confirmed)
      redirect_to new_session_path(resource_name)
      return
    end

    if resource.confirmation_token == code && resource.confirm
      set_flash_message!(:notice, :confirmed)
      sign_in(resource_name, resource)
      respond_with_navigational(resource) { redirect_to after_confirmation_path_for(resource_name, resource) }
    else
      resource.errors.add(:confirmation_token, "is invalid")
      render :show, status: :unprocessable_entity
    end
  end

  protected

  def after_resending_confirmation_instructions_path_for(_resource_name)
    user_confirmation_path(email: resource.email)
  end
end
