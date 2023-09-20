module CleanActions
  class TransactionRunner
    class << self
      def restrict_action_calls_by(method)
        Thread.current[:action_calls_restricted_by] = method
        yield
      ensure
        Thread.current[:action_calls_restricted_by] = nil
      end

      def action_calls_restricted_by
        Thread.current[:action_calls_restricted_by]
      end
    end

    def initialize(action)
      @action = action
    end

    def run(&block)
      performed_actions << @action

      if Thread.current[:transaction_started]
        unless IsolationLevelValidator.can_be_nested(action_isolation_level)
          ErrorReporter.report <<~MSG
            action #{@action.class.name} requires #{action_isolation_level}, run inside #{Thread.current[:root_isolation_level]}
          MSG
        end

        return block.call
      end

      start_transaction(&block)
    end

    private

    delegate :restrict_action_calls_by, to: :class

    def start_transaction(&block)
      Thread.current[:transaction_started] = true
      Thread.current[:root_isolation_level] = action_isolation_level

      ActiveRecord::Base.transaction(isolation: action_isolation_level, requires_new: true) do
        block.call.tap { restrict_action_calls_by(:after_commit) { run_after_commit_actions } }
      rescue => e
        run_rollback_blocks
        raise e unless e.is_a?(ActionFailure)

        e
      end
    ensure
      Thread.current[:root_isolation_level] = nil
      Thread.current[:transaction_started] = false
      run_ensure_blocks
      Thread.current[:performed_actions] = []
    end

    def action_isolation_level
      @action.class.isolation_level
    end

    def run_after_commit_actions
      performed_actions.each(&:after_commit)
    end

    def run_ensure_blocks
      performed_actions.each(&:ensure)
    end

    def run_rollback_blocks
      performed_actions.each(&:rollback)
    end

    def performed_actions
      Thread.current[:performed_actions] ||= []
    end
  end
end
