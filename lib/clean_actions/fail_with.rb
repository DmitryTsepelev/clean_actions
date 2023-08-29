module CleanActions
  module FailWith
    def self.included(base)
      base.extend(ClassMethods)
    end

    def dry_call
      self.class.before_actions_blocks.each_with_object([]) do |b, failures|
        instance_eval(&b)
      rescue CleanActions::ActionFailure => f
        failures << f
      end
    end

    module ClassMethods
      def fail_with(failure_reason, &block)
        before_actions { fail!(failure_reason) if instance_eval(&block) }
      end

      def dry_call(**kwargs)
        new(**kwargs).dry_call
      end
    end
  end
end
