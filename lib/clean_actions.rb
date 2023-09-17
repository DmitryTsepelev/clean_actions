# frozen_string_literal: true

require "active_record"

require "clean_actions/configuration"
require "clean_actions/error_reporter"
require "clean_actions/isolation_level_validator"
require "clean_actions/fail_with"
require "clean_actions/typed_returns"
require "clean_actions/action_failure"
require "clean_actions/transaction_runner"
require "clean_actions/action"
require "clean_actions/base"
require "clean_actions/version"

module CleanActions
  class << self
    def config
      @config ||= Configuration.new
    end
  end
end
