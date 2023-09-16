module CleanActions
  class Action
    class << self
      def call(**kwargs)
        new(**kwargs).call
      end

      def before_actions(&block)
        before_actions_blocks << block
      end

      def before_actions_blocks
        @before_actions_blocks ||= []
      end

      def with_isolation_level(isolation_level)
        IsolationLevelValidator.validate(isolation_level)

        @isolation_level = isolation_level
      end

      def isolation_level
        @isolation_level ||= CleanActions.config.isolation_level
      end
    end

    def call
      perform_before_transaction

      TransactionRunner.new(self).run do
        self.class.before_actions_blocks.each { |b| instance_eval(&b) }
        perform_actions
      end
    end

    def fail!(reason)
      raise ActionFailure.new(reason)
    end

    def perform_actions
    end

    def after_commit
    end

    def ensure
    end

    def rollback
    end

    private

    def perform_before_transaction
      return unless respond_to?(:before_transaction)

      if Thread.current[:transaction_started]
        ErrorReporter.report("#{self.class.name}#before_transaction was called inside the transaction")
      end

      before_transaction
    end
  end
end
