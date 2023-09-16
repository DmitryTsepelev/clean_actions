require "spec_helper"

RSpec.describe CleanActions::Action do
  subject { action_class.call(**action_params) }

  let(:action_params) { {} }

  before do
    allow(CleanActions::ErrorReporter).to receive(:report)
  end

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

  context ".with_isolation_level" do
    let(:action_class) do
      Class.new(CleanActions::Action)
    end

    before do
      allow(ActiveRecord::Base).to receive(:transaction)
    end

    specify do
      subject
      expect(ActiveRecord::Base).to have_received(:transaction).with(isolation: :read_committed, requires_new: true)
    end

    context "when specific level is configured" do
      let(:action_class) do
        Class.new(CleanActions::Action).tap do |action|
          action.with_isolation_level(:repeatable_read)
        end
      end

      it "uses configured level" do
        subject
        expect(ActiveRecord::Base).to have_received(:transaction).with(isolation: :repeatable_read, requires_new: true)
      end
    end

    context "when global level is configured" do
      around(:each) do |example|
        old_isolation_level = CleanActions.config.isolation_level
        CleanActions.config.isolation_level = :repeatable_read
        example.run
        CleanActions.config.isolation_level = old_isolation_level
      end

      it "uses global level" do
        subject
        expect(ActiveRecord::Base).to have_received(:transaction).with(isolation: :repeatable_read, requires_new: true)
      end
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
        subject
        expect(CleanActions::ErrorReporter).to have_received(:report).with("#before_transaction was called inside the transaction")
      end
    end
  end
end
