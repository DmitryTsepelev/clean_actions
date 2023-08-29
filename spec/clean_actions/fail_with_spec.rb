require "spec_helper"

RSpec.describe CleanActions::FailWith do
  describe "#dry_run" do
    subject { action_class.dry_call(**action_params) }

    let(:action_params) { {} }

    let(:action_class) do
      Class.new(CleanActions::Action) do
        include CleanActions::FailWith

        fail_with(:fail1) { @action_params[:value] == 1 }
        fail_with(:fail_odd) { @action_params[:value].odd? }

        def initialize(action_params)
          @action_params = action_params
        end

        def perform_actions
          42
        end
      end
    end

    context "when all fail_with pass" do
      let(:action_params) { {value: 2} }

      it { is_expected.to eq([]) }
    end

    context "when one fail_with fails" do
      let(:action_params) { {value: 3} }

      it { is_expected.to match_array([CleanActions::ActionFailure.new(:fail_odd)]) }
    end

    context "when many fail_with fail" do
      let(:action_params) { {value: 1} }

      it { is_expected.to match_array([CleanActions::ActionFailure.new(:fail_odd), CleanActions::ActionFailure.new(:fail1)]) }
    end
  end

  describe ".fail_with" do
    subject { action_class.call(**action_params) }

    let(:action_params) { {} }

    let(:action_class) do
      Class.new(CleanActions::Action) do
        include CleanActions::FailWith

        fail_with(:invalid_data) { @action_params[:status] == :invalid }

        def initialize(action_params)
          @action_params = action_params
        end

        def perform_actions
          42
        end
      end
    end

    context "when fail_with triggers" do
      let(:action_params) { {status: :invalid} }

      specify do
        expect(subject).to be_a(CleanActions::ActionFailure)
        expect(subject.reason).to eq(:invalid_data)
      end
    end

    context "when fail_with not triggers" do
      let(:action_params) { {status: :valid} }

      specify do
        expect(subject).to eq(42)
      end
    end
  end
end
