RSpec.describe "simple action" do
  let(:raise_standard_error) { false }

  subject { CreateOrder.call(user: user, raise_standard_error: raise_standard_error) }

  before do
    allow(NotifyUserAboutCreatedOrderJob).to receive(:perform_later)
  end

  context "when action succeeds" do
    let(:user) { User.create! }

    specify do
      expect { subject }.to change(Order, :count).by(1)
      expect(subject).to eq(Order.last)
      expect(NotifyUserAboutCreatedOrderJob).to have_received(:perform_later).with(order: Order.last)
    end
  end

  context "when action fails because of fail_with" do
    let(:user) { User.create!(banned: true) }

    specify do
      expect { subject }.to change(Order, :count).by(0)
      expect(subject).to be_a(CleanActions::ActionFailure)
        .and have_attributes(reason: :banned_user)
      expect(NotifyUserAboutCreatedOrderJob).not_to have_received(:perform_later)
    end
  end

  context "when action fails because of StandardError" do
    let(:raise_standard_error) { true }
    let(:user) { User.create! }

    specify do
      expect { subject }.to raise_error(StandardError).and change(Order, :count).by(0)
      expect(NotifyUserAboutCreatedOrderJob).not_to have_received(:perform_later)
    end
  end
end
