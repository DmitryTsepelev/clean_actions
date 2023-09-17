require "spec_helper"

RSpec.describe CleanActions::ErrorReporter do
  subject { described_class.report(message) }

  let(:message) { "message" }

  before do
    allow(Rails.logger).to receive(:info)
  end

  specify do
    expect { subject }.to raise_error(StandardError, message)
    expect(Rails.logger).to have_received(:info).with(message)
  end

  context "when CleanActions.config.raise_errors is off" do
    before do
      CleanActions.config.raise_errors = false
    end

    after do
      CleanActions.config.raise_errors = true
    end

    specify do
      subject
      expect(Rails.logger).to have_received(:info).with(message)
    end
  end
end
