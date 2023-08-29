module CleanActions
  class Base < Action
    include TypedReturns
    include FailWith
  end
end
