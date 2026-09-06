class Users::ConfirmationsController < Devise::ConfirmationsController
  def show
    if params[:confirmation_token].present?
      super
    else
      render_confirm_code_form
    end
  end

  def confirm_code_form
    render_confirm_code_form
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
      redirect_to new_user_session_path
      return
    end

    if resource.confirmation_token == code && resource.confirm
      session.delete(:pending_confirmation_email)
      set_flash_message!(:notice, :confirmed)
      sign_in(resource_name, resource)
      redirect_to after_confirmation_path_for(resource_name, resource), status: :see_other
    else
      resource.errors.add(:confirmation_token, "is invalid")
      render :show, status: :unprocessable_entity
    end
  end

  protected

  def after_resending_confirmation_instructions_path_for(_resource_name)
    user_confirm_code_path(email: resource.email)
  end

  private

  def render_confirm_code_form
    self.resource = resource_class.new
    resource.email = params[:email].presence || session[:pending_confirmation_email]
    render :show
  end
end
