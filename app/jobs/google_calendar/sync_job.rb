# frozen_string_literal: true

module GoogleCalendar
  class SyncJob < ApplicationJob
    queue_as :default

    def perform
      return unless Client.configured?

      result = InboundSync.call
      Rails.logger.info("GoogleCalendar::SyncJob finished: #{result.inspect}")
      result
    end
  end
end
