module CleanActions
  class IsolationLevelValidator
    VALID_ISOLATION_LEVELS = %i[read_uncommited read_committed repeatable_read]

    class << self
      def validate(isolation_level, allow_serializable: false)
        if isolation_level == :serializable
          unless allow_serializable
            ErrorReporter.report("serializable isolation should only be used for a whole project, please use global config")
          end

          return
        end

        return if VALID_ISOLATION_LEVELS.include?(isolation_level)

        ErrorReporter.report("invalid isolation level #{isolation_level} for #{name}")
      end

      def can_be_nested(isolation_level)
        CleanActions.config.isolation_level == :serializable ||
          VALID_ISOLATION_LEVELS.index(isolation_level) <= VALID_ISOLATION_LEVELS.index(Thread.current[:root_isolation_level])
      end
    end
  end
end
