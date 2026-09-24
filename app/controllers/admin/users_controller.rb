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

    def destroy_access_code
      user = User.find(params[:id])
      access_code = user.access_code

      unless access_code
        redirect_back fallback_location: admin_root_path, alert: "No active door code for this user."
        return
      end

      code = access_code.code
      TtLock::AccessCodeRevoker.call(access_code)
      redirect_back fallback_location: admin_root_path,
        notice: "Door code #{code} deleted for #{user.email}."
    rescue TtLock::Error => e
      redirect_back fallback_location: admin_root_path,
        alert: "Could not delete door code on the lock: #{e.message}"
    end
  end
end
