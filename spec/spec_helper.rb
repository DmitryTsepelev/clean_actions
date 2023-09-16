# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "redis"
require_relative "dummy/config/environment"

require "rspec/rails"

require "clean_actions"

RSpec.configure do |config|
  # For proper work of ActiveSupport::CurrentAttributes reset
  config.include ActiveSupport::CurrentAttributes::TestHelper

  config.example_status_persistence_file_path = ".rspec_status"
  config.infer_base_class_for_anonymous_controllers = true

  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do |e|
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

ActiveRecord::Base.establish_connection(ENV["DATABASE_URL"] || {adapter: "postgresql",
                                                                database: "clean_actions_test"})

load File.dirname(__FILE__) + "/dummy/db/schema.rb"
