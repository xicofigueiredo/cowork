module Admin
  class UsersController < BaseController
    def issue_access_code
      user = User.find(params[:id])
      access_code = TtLock::AccessCodeIssuer.ensure_for_user!(user)

      if access_code&.synced_to_lock?
        redirect_back fallback_location: admin_root_path,
          notice: "Door code #{access_code.code} issued for #{user.email}."
      else
        redirect_back fallback_location: admin_root_path,
          alert: "Could not push door code to the lock. Check the gateway and try again."
      end
    rescue TtLock::Error => e
      redirect_back fallback_location: admin_root_path,
        alert: "Could not push door code to the lock: #{e.message}"
    end
  end
end
