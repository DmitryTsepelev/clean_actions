module CleanActions
  class TransactionRunner
    def initialize(action)
      @action = action
    end

    def run(&block)
      performed_actions << @action

      return block.call if Thread.current[:transaction_started]

      start_transaction(&block)
    end

    private

    def start_transaction(&block)
      Thread.current[:transaction_started] = true

      ActiveRecord::Base.transaction(requires_new: true) do
        block.call.tap { run_after_commit_actions }
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
