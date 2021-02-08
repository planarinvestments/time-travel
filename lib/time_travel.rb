require 'rails'
require "time_travel/railtie"
require "time_travel/sql_function_helper"
require "time_travel/configuration"

module TimeTravel
  INFINITE_DATE = Time.find_zone('UTC').local(3000,1,1)
  PRECISE_TIME_FORMAT = "%Y-%m-%d %H:%M:%S.%6N"

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end

require "time_travel/timeline"
require "time_travel/timeline_helper"
