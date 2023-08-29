require "spec_helper"

RSpec.describe CleanActions::TransactionRunner do
  def expect_inside_block(action, &block)
    described_class.new(action).run(&block)
  end

  let(:action) { action_class.new }

  let(:action_class) do
    Class.new(CleanActions::Action) do
      attr_reader :after_commit_happened, :ensure_happened

      def after_commit
        @after_commit_happened = true
      end

      def ensure
        @ensure_happened = true
      end
    end
  end

  context "when action executes successfully" do
    specify do
      expect_inside_block(action) do
        expect(Thread.current[:performed_actions]).to eq([action])
        expect(Thread.current[:transaction_started]).to eq(true)
      end

      expect(action.after_commit_happened).to eq(true)
      expect(action.ensure_happened).to eq(true)
      expect(Thread.current[:transaction_started]).to eq(false)
      expect(Thread.current[:performed_actions]).to be_empty
    end
  end

  context "when action calls fail!" do
    specify do
      expect_inside_block(action) do
        expect(Thread.current[:performed_actions]).to eq([action])
        expect(Thread.current[:transaction_started]).to eq(true)

        raise CleanActions::ActionFailure, :invalid_data
      end

      expect(action.after_commit_happened).to be_falsey
      expect(action.ensure_happened).to eq(true)
      expect(Thread.current[:transaction_started]).to eq(false)
      expect(Thread.current[:performed_actions]).to be_empty
    end
  end

  context "when action raises ActiveRecord::Rollback" do
    let(:rollback_error) { ActiveRecord::Rollback.new }

    specify do
      expect do
        expect_inside_block(action) do
          expect(Thread.current[:performed_actions]).to eq([action])
          expect(Thread.current[:transaction_started]).to eq(true)

          raise rollback_error
        end
      end.not_to raise_error

      expect(action.after_commit_happened).to be_falsey
      expect(action.ensure_happened).to eq(true)
      expect(Thread.current[:transaction_started]).to eq(false)
      expect(Thread.current[:performed_actions]).to be_empty
    end
  end

  context "when action raises StandardError" do
    let(:standard_error) { StandardError.new }

    specify do
      expect do
        expect_inside_block(action) do
          expect(Thread.current[:performed_actions]).to eq([action])
          expect(Thread.current[:transaction_started]).to eq(true)

          raise standard_error
        end
      end.to raise_error(standard_error)

      expect(action.after_commit_happened).to be_falsey
      expect(action.ensure_happened).to eq(true)
      expect(Thread.current[:transaction_started]).to eq(false)
      expect(Thread.current[:performed_actions]).to be_empty
    end
  end

  context "when another action is executed inside" do
    let(:nested_action) { action_class.new }

    specify do
      expect_inside_block(action) do
        expect(Thread.current[:performed_actions]).to eq([action])
        expect(Thread.current[:transaction_started]).to eq(true)

        expect_inside_block(nested_action) do
          expect(Thread.current[:performed_actions]).to eq([action, nested_action])
          expect(Thread.current[:transaction_started]).to eq(true)
        end

        expect(Thread.current[:transaction_started]).to eq(true)
      end

      expect(action.after_commit_happened).to be_truthy
      expect(action.ensure_happened).to eq(true)
      expect(nested_action.after_commit_happened).to be_truthy

      expect(Thread.current[:transaction_started]).to eq(false)
      expect(Thread.current[:performed_actions]).to be_empty
    end

    context "when nested action fails" do
      specify do
        expect_inside_block(action) do
          expect(Thread.current[:performed_actions]).to eq([action])
          expect(Thread.current[:transaction_started]).to eq(true)

          expect_inside_block(nested_action) do
            expect(Thread.current[:performed_actions]).to eq([action, nested_action])
            expect(Thread.current[:transaction_started]).to eq(true)

            raise CleanActions::ActionFailure, :invalid_data
          end

          expect(Thread.current[:transaction_started]).to eq(true)
        end

        expect(action.after_commit_happened).to be_falsey
        expect(action.ensure_happened).to eq(true)
        expect(nested_action.after_commit_happened).to be_falsey

        expect(Thread.current[:transaction_started]).to eq(false)
        expect(Thread.current[:performed_actions]).to be_empty
      end
    end
  end
end
