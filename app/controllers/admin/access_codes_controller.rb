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
    end

    def create
      unless TtLock::Client.configured?
        redirect_to new_admin_access_code_path, alert: "TTLock is not configured. Set TTLOCK_* env vars first."
        return
      end

      valid_from = parse_datetime(params[:valid_from])
      valid_to = parse_datetime(params[:valid_to])
      name = params[:name].to_s.strip.presence || "Manual code"
      code = params[:code].to_s.strip.presence

      if code.present? && !code.match?(/\A\d{4,9}\z/)
        redirect_to new_admin_access_code_path, alert: "Code must be 4–9 digits."
        return
      end

      access_code = TtLock::AccessCodeIssuer.call(
        name: name,
        valid_from: valid_from,
        valid_to: valid_to,
        source: "manual",
        user: current_user,
        code: code
      )

      redirect_to admin_access_codes_path, notice: "Door code #{access_code.code} created."
    rescue ArgumentError
      redirect_to new_admin_access_code_path, alert: "Invalid date or time."
    rescue TtLock::Error => e
      redirect_to new_admin_access_code_path, alert: "Could not add code to the lock: #{e.message}"
    end

    def destroy
      TtLock::AccessCodeRevoker.call(@access_code)
      redirect_to admin_access_codes_path, notice: "Door code revoked."
    rescue TtLock::Error => e
      redirect_to admin_access_codes_path, alert: "Could not revoke code on the lock: #{e.message}"
    end

    private

    def set_access_code
      @access_code = AccessCode.find(params[:id])
    end

    def parse_datetime(value)
      raise ArgumentError, "missing datetime" if value.blank?

      Time.zone.parse(value.to_s) || raise(ArgumentError, "invalid datetime")
    end
  end
end
