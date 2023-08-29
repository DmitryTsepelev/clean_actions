require "spec_helper"

RSpec.describe CleanActions::TypedReturns do
  subject { action_class.call(**action_params) }

  let(:action_params) { {} }

  context "when returns is not configured" do
    let(:action_class) do
      Class.new(CleanActions::Action) do
        include CleanActions::TypedReturns

        def perform_actions
          42
        end
      end
    end

    it { is_expected.to be_nil }

    context "when ActionFailure is returned" do
      let(:action_class) do
        Class.new(CleanActions::Action) do
          include CleanActions::TypedReturns

          def perform_actions
            fail!(:invalid_data)
          end
        end
      end

      specify do
        expect(subject).to be_a(CleanActions::ActionFailure)
        expect(subject.reason).to eq(:invalid_data)
      end
    end
  end

  context "when returns is configured" do
    context "when correct type is returned" do
      let(:action_class) do
        Class.new(CleanActions::Action) do
          include CleanActions::TypedReturns

          returns Integer

          def perform_actions
            42
          end
        end
      end

      it "returns value" do
        expect(subject).to eq(42)
      end
    end

    context "when incorrect type is returned" do
      let(:action_class) do
        Class.new(CleanActions::Action) do
          include CleanActions::TypedReturns

          returns String

          def perform_actions
            42
          end
        end
      end

      specify do
        expect { subject }.to raise_error(
          StandardError,
          "expected  to return String, returned 42"
        )
      end
    end

    context "when ActionFailure is returned" do
      let(:action_class) do
        Class.new(CleanActions::Action) do
          include CleanActions::TypedReturns

          returns Integer

          def perform_actions
            fail!(:invalid_data)
          end
        end
      end

      specify do
        expect(subject).to be_a(CleanActions::ActionFailure)
        expect(subject.reason).to eq(:invalid_data)
      end
    end

    context "when multiple types are allowed" do
      context "when correct type is returned" do
        let(:action_class) do
          Class.new(CleanActions::Action) do
            include CleanActions::TypedReturns

            returns Integer, Hash

            def perform_actions
              42
            end
          end
        end

        it "returns value" do
          expect(subject).to eq(42)
        end
      end

      context "when incorrect type is returned" do
        let(:action_class) do
          Class.new(CleanActions::Action) do
            include CleanActions::TypedReturns

            returns String, Hash

            def perform_actions
              42
            end
          end
        end

        specify do
          expect { subject }.to raise_error(
            StandardError,
            "expected  to return String, Hash, returned 42"
          )
        end
      end
    end
  end
end
