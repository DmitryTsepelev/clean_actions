module CleanActions
  class ErrorReporter
    def self.report(message)
      Rails.logger.info(message)

      raise message if CleanActions.config.raise_errors?
    end
  end
end
