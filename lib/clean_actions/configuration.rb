module CleanActions
  class Configuration
    attr_accessor :raise_errors

    def initialize
      @raise_errors = Rails.env.development? || Rails.env.test?
    end

    alias_method :raise_errors?, :raise_errors
  end
end
