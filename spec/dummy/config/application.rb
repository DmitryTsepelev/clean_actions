# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_job/railtie"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    config.root = File.join(__dir__, "..")
    config.logger = Logger.new("/dev/null")
    config.api_only = true

    if Rails::VERSION::MAJOR >= 7
      config.active_record.async_query_executor = :global_thread_pool
    end
  end
end
