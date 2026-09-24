module Admin
  class AccessCodesController < BaseController
    before_action :set_access_code, only: [ :destroy ]

    def index
      @access_codes = AccessCode.includes(:user, :booking).recent_first.limit(100)
      @ttlock_configured = TtLock::Client.configured?
    end

    def new
      @access_code = AccessCode.new(
        valid_from: Time.zone.now.change(min: 0, sec: 0),
        valid_to: Time.zone.now.change(hour: 20, min: 0, sec: 0)
      )
      @ttlock_configured = TtLock::Client.configured?
      load_users
    end

    def create
      unless TtLock::Client.configured?
        redirect_to new_admin_access_code_path, alert: "TTLock is not configured. Set TTLOCK_* env vars first."
        return
      end

      permanent = params[:validity_type].to_s == "permanent"
      valid_from = permanent ? Time.current : parse_datetime(params[:valid_from])
      valid_to = permanent ? AccessCode.permanent_until : parse_datetime(params[:valid_to])
      name = params[:name].to_s.strip.presence || "Manual code"
      code = params[:code].to_s.strip.presence
      user = User.find_by(id: params[:user_id]) if params[:user_id].present?

      if code.present? && !code.match?(/\A\d{4,9}\z/)
        redirect_to new_admin_access_code_path, alert: "Code must be 4–9 digits."
        return
      end

      if user&.access_code&.active?
        TtLock::AccessCodeRevoker.call(user.access_code)
      end

      access_code = TtLock::AccessCodeIssuer.call(
        name: name,
        valid_from: valid_from,
        valid_to: valid_to,
        permanent: permanent,
        source: "manual",
        user: user,
        code: code
      )

      notice = if user
        "Door code #{access_code.code} created for #{user.email}."
      else
        "Door code #{access_code.code} created."
      end
      redirect_to admin_access_codes_path, notice: notice
    rescue ArgumentError
      redirect_to new_admin_access_code_path, alert: "Invalid date or time."
    rescue TtLock::Error => e
      redirect_to new_admin_access_code_path, alert: "Could not add code to the lock: #{e.message}"
    end

    def destroy
      code = @access_code.code
      TtLock::AccessCodeRevoker.call(@access_code)
      redirect_to admin_access_codes_path, notice: "Door code #{code} deleted."
    rescue TtLock::Error => e
      redirect_to admin_access_codes_path, alert: "Could not delete door code on the lock: #{e.message}"
    end

    private

    def load_users
      @users = User.order(:first_name, :last_name, :email)
    end

    def set_access_code
      @access_code = AccessCode.find(params[:id])
    end

    def parse_datetime(value)
      raise ArgumentError, "missing datetime" if value.blank?

      Time.zone.parse(value.to_s) || raise(ArgumentError, "invalid datetime")
    end
  end
end
