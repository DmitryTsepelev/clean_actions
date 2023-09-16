module CleanActions
  class Configuration
    attr_accessor :raise_errors

    def initialize
      @raise_errors = Rails.env.development? || Rails.env.test?
    end

    def isolation_level=(isolation_level)
      IsolationLevelValidator.validate(isolation_level, allow_serializable: true)
      @isolation_level = isolation_level
    end

    def isolation_level
      @isolation_level ||= :read_committed
    end

    alias_method :raise_errors?, :raise_errors
  end
end
