module TimeTravel
  class Configuration
    attr_accessor :update_mode

    def initialize
      @update_mode="native"
    end
  end
end
