class CreateOrder < CleanActions::Base
  returns Order

  fail_with(:banned_user) { @user.banned? }

  def initialize(user:, raise_standard_error: false)
    @user = user
    @raise_standard_error = raise_standard_error
  end

  def perform_actions
    raise StandardError if @raise_standard_error

    @order = @user.orders.find_or_create_by!(status: "cart")
  end

  def after_commit
    NotifyUserAboutCreatedOrderJob.perform_later(order: @order)
  end
end
