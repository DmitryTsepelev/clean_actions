# frozen_string_literal: true

require_relative "lib/clean_actions/version"

Gem::Specification.new do |spec|
  spec.name = "clean_actions"
  spec.version = CleanActions::VERSION
  spec.authors = ["DmitryTsepelev"]
  spec.email = ["dmitry.a.tsepelev@gmail.com"]
  spec.homepage = "https://github.com/DmitryTsepelev/clean_actions"
  spec.summary = "fill"

  spec.license = "MIT"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/DmitryTsepelev/clean_actions/issues",
    "changelog_uri" => "https://github.com/DmitryTsepelev/clean_actions/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://github.com/DmitryTsepelev/clean_actions/blob/master/README.md",
    "homepage_uri" => "https://github.com/DmitryTsepelev/clean_actions",
    "source_code_uri" => "https://github.com/DmitryTsepelev/clean_actions"
  }

  spec.files = [
    Dir.glob("lib/**/*"),
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ].flatten

  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7.0"

  spec.add_dependency "rails", ">= 6.1"
  spec.add_development_dependency "redis", ">= 4.0"
  spec.add_development_dependency "prometheus-client"
end
