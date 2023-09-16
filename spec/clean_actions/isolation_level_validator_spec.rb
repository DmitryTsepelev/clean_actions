require "spec_helper"

RSpec.describe CleanActions::IsolationLevelValidator do
  subject { described_class.validate(isolation_level, allow_serializable: allow_serializable) }

  let(:isolation_level) { :repeatable_read }
  let(:allow_serializable) { false }

  before do
    allow(CleanActions::ErrorReporter).to receive(:report)
  end

  around(:each) do |example|
    old_isolation_level = CleanActions.config.isolation_level
    CleanActions.config.isolation_level = :read_committed
    example.run
    CleanActions.config.isolation_level = old_isolation_level
  end

  specify do
    subject
    expect(CleanActions::ErrorReporter).not_to have_received(:report)
  end

  context "when serializable is passed" do
    let(:isolation_level) { :serializable }

    specify do
      subject
      expect(CleanActions::ErrorReporter).to have_received(:report).with(
        "serializable isolation should only be used for a whole project, please use global config"
      )
    end
  end

  context "when allow_serializable is true" do
    let(:allow_serializable) { true }

    specify do
      subject
      expect(CleanActions::ErrorReporter).not_to have_received(:report)
    end

    context "when serializable is passed" do
      let(:isolation_level) { :serializable }

      specify do
        subject
        expect(CleanActions::ErrorReporter).not_to have_received(:report)
      end
    end
  end
end
