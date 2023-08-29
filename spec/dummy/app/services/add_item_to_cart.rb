class AddItemToCart < CleanActions::Base
  returns OrderItem

  fail_with(:out_of_stock) { @item.in_stock == 0 }

  def initialize(user:, item:)
    @user = user
    @item = item
  end

  def perform_actions
    @order = CreateOrder.call(user: @user)
    @order_item = @order.order_items
      .create_with(quantity: 0)
      .find_or_create_by!(item: @item)
  end

  def after_commit
    NotifyUserAboutUpdatedOrderItemJob.perform_later(order_item: @order_item)
  end
end
