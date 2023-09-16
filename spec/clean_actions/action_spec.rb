require "spec_helper"

RSpec.describe CleanActions::Action do
  subject { action_class.call(**action_params) }

  let(:action_params) { {} }

  context "#perform_actions" do
    let(:ensured_service) { instance_double "EnsuredService" }
    let(:transactional_service) { instance_double "TransactionalService" }

    let(:action_class) do
      e_service = ensured_service
      service = transactional_service

      Class.new(CleanActions::Action).tap do |action|
        action.define_method(:ensure) { e_service.call }

        action.define_method(:perform_actions) do
          service.call
          42
        end
      end
    end

    before do
      allow(ensured_service).to receive(:call)
      allow(transactional_service).to receive(:call)
    end

    specify do
      expect(subject).to eq(42)
      expect(transactional_service).to have_received(:call)
      expect(ensured_service).to have_received(:call)
    end
  end

  context "#after_commit" do
    let(:ensured_service) { instance_double "EnsuredService" }
    let(:after_commit_service) { instance_double "AfterCommitService" }

    let(:action_class) do
      e_service = ensured_service
      ac_service = after_commit_service

      Class.new(CleanActions::Action).tap do |action|
        action.define_method(:after_commit) { ac_service.call }
        action.define_method(:ensure) { e_service.call }
      end
    end

    before do
      allow(ensured_service).to receive(:call)
      allow(after_commit_service).to receive(:call)
    end

    specify do
      expect(subject).to be_nil
      expect(after_commit_service).to have_received(:call)
      expect(ensured_service).to have_received(:call)
    end
  end

  context "#fail!" do
    let(:ensured_service) { instance_double "EnsuredService" }

    let(:action_class) do
      service = ensured_service

      Class.new(CleanActions::Action).tap do |action|
        action.define_method(:perform_actions) do
          fail!(:invalid_data)
        end

        action.define_method(:ensure) do
          service.call
        end
      end
    end

    before do
      allow(ensured_service).to receive(:call)
    end

    specify do
      expect(subject).to be_a(CleanActions::ActionFailure)
      expect(subject.reason).to eq(:invalid_data)
      expect(ensured_service).to have_received(:call)
    end
  end

  context ".before_transaction_blocks" do
    let(:before_transaction_service) { instance_double "before_transactionService" }

    let(:action_class) do
      service = before_transaction_service

      Class.new(CleanActions::Action).tap do |action|
        action.define_method(:before_transaction) do
          service.call
        end
      end
    end

    before do
      allow(before_transaction_service).to receive(:call)
    end

    specify do
      expect(subject).to be_nil
      expect(before_transaction_service).to have_received(:call)
    end

    context "when transaction was already in progress" do
      before do
        Thread.current[:transaction_started] = true
      end

      after do
        Thread.current[:transaction_started] = false
      end

      specify do
        expect { subject }.to raise_exception(
          StandardError, "#before_transaction was called inside the transaction"
        )
      end
    end
  end
end
