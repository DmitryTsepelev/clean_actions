module CleanActions
  class ActionFailure < ActiveRecord::Rollback
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super
    end

    def ==(other)
      reason == other.reason
    end
  end
end
