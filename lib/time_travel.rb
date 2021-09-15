require 'rails'
require "time_travel/railtie"
require "time_travel/sql_function_helper"
require "time_travel/configuration"

module TimeTravel
  INFINITE_DATE = Time.new(3000,1,1,0,0,0,"+00:00")
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
