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
    end

    def call
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
  end
end
