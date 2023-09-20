require "spec_helper"

RSpec.describe CleanActions::Action do
  subject { action_class.call(**action_params) }

  let(:action_params) { {} }

  before do
    allow(CleanActions::ErrorReporter).to receive(:report)
  end

  context "#perform_actions" do
    let(:ensured_body) { instance_double "EnsuredBody" }
    let(:transactional_body) { instance_double "TransactionalBody" }

    let(:action_class) do
      e_body = ensured_body
      t_body = transactional_body

      Class.new(CleanActions::Action).tap do |action|
        action.define_method(:ensure) { e_body.call }

        action.define_method(:perform_actions) do
          t_body.call
          42
        end
      end
    end

    before do
      allow(ensured_body).to receive(:call)
      allow(transactional_body).to receive(:call)
    end

    specify do
      expect(subject).to eq(42)
      expect(transactional_body).to have_received(:call)
      expect(ensured_body).to have_received(:call)
    end
  end

  context "#after_commit" do
    let(:ensured_body) { instance_double "EnsuredBody" }
    let(:after_commit_body) { instance_double "AfterCommitBody" }

    let(:action_class) do
      e_body = ensured_body
      ac_body = after_commit_body

      Class.new(CleanActions::Action).tap do |action|
        action.define_method(:after_commit) { ac_body.call }
        action.define_method(:ensure) { e_body.call }
      end
    end

    context "when valid body is used" do
      before do
        allow(ensured_body).to receive(:call)
        allow(after_commit_body).to receive(:call)
      end

      specify do
        expect(subject).to be_nil
        expect(after_commit_body).to have_received(:call)
        expect(ensured_body).to have_received(:call)
      end
    end

    context "when another service is called inside after_commit" do
      let(:after_commit_body) { Class.new(CleanActions::Action) }

      before do
        allow(ensured_body).to receive(:call)
      end

      specify do
        expect(subject).to be_nil
        expect(ensured_body).to have_received(:call)
        expect(CleanActions::ErrorReporter).to have_received(:report).with(
          "calling action  is resticted inside #after_commit"
        )
      end
    end
  end

  context "#fail!" do
    let(:ensured_body) { instance_double "EnsuredBody" }

    let(:action_class) do
      body = ensured_body

      Class.new(CleanActions::Action).tap do |action|
        action.define_method(:perform_actions) do
          fail!(:invalid_data)
        end

        action.define_method(:ensure) do
          body.call
        end
      end
    end

    before do
      allow(ensured_body).to receive(:call)
    end

    specify do
      expect(subject).to be_a(CleanActions::ActionFailure)
      expect(subject.reason).to eq(:invalid_data)
      expect(ensured_body).to have_received(:call)
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
    let(:before_transaction_body) { instance_double "BeforeTransactionBody" }

    let(:action_class) do
      body = before_transaction_body

      Class.new(CleanActions::Action).tap do |action|
        action.define_method(:before_transaction) do
          body.call
        end
      end
    end

    before do
      allow(before_transaction_body).to receive(:call)
    end

    specify do
      expect(subject).to be_nil
      expect(before_transaction_body).to have_received(:call)
    end

    context "when transaction was already in progress" do
      around(:each) do |example|
        Thread.current[:transaction_started] = true
        Thread.current[:root_isolation_level] = :read_committed
        example.run
        Thread.current[:transaction_started] = false
        Thread.current[:root_isolation_level] = nil
      end

      specify do
        subject
        expect(CleanActions::ErrorReporter).to have_received(:report).with("#before_transaction was called inside the transaction")
      end
    end
  end

  context "#rollback" do
    let(:rollback_body) { instance_double "RollbackBody" }

    before do
      allow(rollback_body).to receive(:call)
    end

    context "when action succeeds" do
      let(:action_class) do
        r_body = rollback_body

        Class.new(CleanActions::Action).tap do |action|
          action.define_method(:rollback) { r_body.call }
        end
      end

      specify do
        expect(subject).to be_nil
        expect(rollback_body).not_to have_received(:call)
      end
    end

    context "when action fails" do
      let(:action_class) do
        r_body = rollback_body

        Class.new(CleanActions::Action).tap do |action|
          action.define_method(:perform_actions) do
            fail!(:invalid_data)
          end

          action.define_method(:rollback) { r_body.call }
        end
      end

      specify do
        expect(subject).to be_a(CleanActions::ActionFailure)
        expect(subject.reason).to eq(:invalid_data)
        expect(rollback_body).to have_received(:call)
      end
    end
  end

  context "#before_actions" do
    let(:before_actions_body) { instance_double "BeforeActionsBody" }

    context "when valid body is used" do
      before do
        allow(before_actions_body).to receive(:call)
      end

      context "when action succeeds" do
        let(:action_class) do
          ba_body = before_actions_body

          Class.new(CleanActions::Action).tap do |action|
            action.before_actions { ba_body.call }
          end
        end

        specify do
          expect(subject).to be_nil
          expect(before_actions_body).to have_received(:call)
        end
      end
    end

    context "when another action is executed inside" do
      let(:nested_action) { Class.new(CleanActions::Action).new }

      let(:action_class) do
        n_action = nested_action

        Class.new(CleanActions::Action).tap do |action|
          action.before_actions { n_action.call }
        end
      end

      specify do
        expect(subject).to be_nil
        expect(CleanActions::ErrorReporter).to have_received(:report)
      end
    end
  end
end
