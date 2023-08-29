# frozen_string_literal: true

RSpec.describe CleanActions do
  subject { described_class }

  it "has a version number" do
    expect(subject::VERSION).not_to be nil
  end
end
