RSpec.describe "nested action" do
  let(:item) { Item.create(name: "iPhone 4S", in_stock: 10) }

  subject { AddItemToCart.call(user: user, item: item) }

  before do
    allow(NotifyUserAboutCreatedOrderJob).to receive(:perform_later)
    allow(NotifyUserAboutUpdatedOrderItemJob).to receive(:perform_later)
  end

  context "when both actions succeed" do
    let(:user) { User.create! }

    specify do
      expect { subject }.to change(Order, :count).by(1).and change(OrderItem, :count).by(1)
      expect(subject).to eq(OrderItem.last)

      expect(NotifyUserAboutCreatedOrderJob).to have_received(:perform_later).with(order: Order.last)
      expect(NotifyUserAboutUpdatedOrderItemJob).to have_received(:perform_later).with(order_item: OrderItem.last)
    end
  end

  context "when nested action fails" do
    let(:user) { User.create!(banned: true) }

    specify do
      expect { subject }.to change(Order, :count).by(0).and change(OrderItem, :count).by(0)
      expect(subject).to be_a(CleanActions::ActionFailure)
        .and have_attributes(reason: :banned_user)

      expect(NotifyUserAboutCreatedOrderJob).not_to have_received(:perform_later)
      expect(NotifyUserAboutUpdatedOrderItemJob).not_to have_received(:perform_later)
    end
  end

  context "when parent action fails" do
    let(:user) { User.create! }
    let(:item) { Item.create(name: "iPhone 4S", in_stock: 0) }

    specify do
      expect { subject }.to change(Order, :count).by(0).and change(OrderItem, :count).by(0)
      expect(subject).to be_a(CleanActions::ActionFailure)
        .and have_attributes(reason: :out_of_stock)

      expect(NotifyUserAboutCreatedOrderJob).not_to have_received(:perform_later)
      expect(NotifyUserAboutUpdatedOrderItemJob).not_to have_received(:perform_later)
    end
  end
end
