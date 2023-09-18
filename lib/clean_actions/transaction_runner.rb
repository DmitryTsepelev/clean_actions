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

      return block.call if Thread.current[:transaction_started]

      start_transaction(&block)
    end

    private

    delegate :restrict_action_calls_by, to: :class

    def start_transaction(&block)
      Thread.current[:transaction_started] = true
      isolation_level = @action.class.isolation_level

      # TODO: validate isolation level for nested transaction
      ActiveRecord::Base.transaction(isolation: isolation_level, requires_new: true) do
        block.call.tap { restrict_action_calls_by(:after_commit) { run_after_commit_actions } }
      rescue => e
        run_rollback_blocks
        raise e unless e.is_a?(ActionFailure)

        e
      end
    ensure
      Thread.current[:transaction_started] = false
      run_ensure_blocks
      Thread.current[:performed_actions] = []
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
