# frozen_string_literal: true

module GoogleCalendar
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end
end
