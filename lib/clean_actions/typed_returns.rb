module CleanActions
  module TypedReturns
    def self.included(base)
      base.prepend(PrependedMethods)
      base.extend(ClassMethods)
    end

    module PrependedMethods
      def call(**)
        returned_value = super

        return returned_value if returned_value.is_a?(ActionFailure)

        if self.class.returned_classes.nil?
          returned_value = nil
        elsif self.class.returned_classes.none? { returned_value.is_a?(_1) }
          ErrorReporter.report(
            "expected #{self.class.name} to return #{self.class.returned_classes.map(&:name).join(", ")}, " \
            "returned #{returned_value.inspect}"
          )
        end

        returned_value
      end
    end

    module ClassMethods
      attr_reader :returned_classes

      def returns(*klasses)
        @returned_classes = klasses
      end
    end
  end
end
