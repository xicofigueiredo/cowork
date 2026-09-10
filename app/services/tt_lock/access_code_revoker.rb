# frozen_string_literal: true

module TtLock
  class AccessCodeRevoker
    def self.call(access_code)
      new(access_code).call
    end

    def initialize(access_code)
      @access_code = access_code
    end

    def call
      return nil unless @access_code
      return @access_code if @access_code.revoked?

      if @access_code.ttlock_keyboard_pwd_id.present? && Client.configured?
        begin
          Client.new.delete_passcode!(@access_code.ttlock_keyboard_pwd_id)
        rescue Error => e
          Rails.logger.error(
            "TTLock access code revoke failed for ##{@access_code.id}: #{e.class}: #{e.message}"
          )
          raise if @access_code.manual?
        end
      end

      @access_code.update!(status: "revoked")
      @access_code
    end
  end
end
