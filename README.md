# CleanActions

[![Gem Version](https://badge.fury.io/rb/clean_actions.svg)](https://rubygems.org/gems/clean_actions)
[![Tests status](https://github.com/DmitryTsepelev/clean_actions/actions/workflows/test.yml/badge.svg)](https://github.com/DmitryTsepelev/clean_actions/actions/workflows/test.yml)
![](https://ruby-gem-downloads-badge.herokuapp.com/clean_actions?type=total)

A modern modular service object toolkit for Rails, that respects database transactions and adds type checks to returned values.

```ruby
class AddItemToCart < CleanActions::Base
  includes Dry::Initializer

  option :user
  option :item

  # This will report an error if someone accidentally returns wrong instance from #perform_actions.
  returns OrderItem

  # Such checks are happening inside the transaction right before #perform_actions, so
  # you can halt early.
  fail_with(:banned_user) { @user.banned? }

  # This method is executed inside the database transaction.
  # If transaction was opened by another action, which called this one - savepoint won't be created.
  # Last line will be used as a returned value.
  def perform_actions
    @order = CreateOrder.call(user: @user) # if CreateOrder fails - transaction will be rolled back
    @order.order_items.create!(item: @item) # if something else fails here - transaction will be rolled back as well
  end

  # This method will be called for each action after whole transaction commits successfully.
  def after_commit
    ItemAddedSubscription.trigger(order: @order)
  end
end
```

## Usage

Add this line to your application's Gemfile:

```ruby
gem 'clean_actions'
```

## Writing your actions

Inherit your actions from `CleanActions::Base`, which by defaut includes [typed returns](/README.md#Typed-Returns) and [fail_with](/README.md#Fail-With).

> If you want to exclude something — inherit from `CleanActions::Action` and configure all includes you need.

You should implement at least one of two methods—`#perform_actions` or `#after_commit`:

```ruby
class AddItemToCart < CleanActions::Base
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
```

When first action is called, it will be wrapped to the database transaction, and all actions called by it will be inside the same transaction. All `#perform_actions` will happen inside the transaction (and rolled back if needed). After that, in case of successful commit, all `#after_commit` actions will happen in order.

## Error handling

If something goes wrong and transaction will raise an error—it will cause transaction to be rolled back. Errors should not be used as a way to manage a control flow, so all unhandled exceptions raised inside actions, will be reraised.

However, if you do expect an error—it's better to represent it as a returned value. Use `#fail!(:reason)` for that:

```ruby
class AddItemToCart < CleanActions::Base
  def perform_actions
    fail!(:shop_is_closed)
  end
end

AddItemToCart.call # => CleanActions::ActionFailure(reason: :shop_is_closed)
```

## Typed Returns

Have you ever been in situation, when it's not clear, what will be returned by the class? Do you have some type system in your project? While you are setting it up—use typed returns:

```ruby
class FetchOrder < CleanActions::Base
  returns Order

  option :order_id

  def perform_actions
    User.find(order_id)
  end
end

FetchOrder.call(42) # => "expected FetchOrder to return Order, returned User" is logged
```

The last line of `#perform_actions` will be returned. Note that if you have this module on but configure nothing—action will return `nil`.

## Isolation levels

By default transactions are executed in `READ COMMITTED` level. You can override it for a specific aciton:

```ruby
class FetchOrder < CleanActions::Base
  with_isolation_level :repeatable_read

  option :order_id

  def perform_actions
    # actions
  end
end

FetchOrder.call(42) # => "expected FetchOrder to return Order, returned User" is logged
```

Also, you can configure it for the whole project:

```ruby
CleanActions.config.isolation_level = :serializable
```

## Error configuration

When something weird happens during the action execution, the message is sent to the Rails log. Also, errors are _raised_ in development and test environments. To change that you can use `.config` object:

```ruby
CleanActions.config.raise_errors = true
```

Here is a list of errors affected by this config:

- type mismatch from (Typed Returns)[/README.md#Typed-Returns];
- action with (#before_transaction)[/README.md#before_transaction] is called inside the transaction;
- invalid isolation levels.

## Advanced Lifecycle

This section contains some additional hooks to improve your actions.

### before_transaction

If you want to do something outside the transaction (e.g., some IO operation)—use `before_transaction`:

```ruby
class SyncData < CleanActions::Base
  def before_transaction
    @response = ApiClient.fetch
  end

  def perform_actions
    # use response
  end
end
```

Please note, that error will be risen if this action will be called from another action (and transaction will be already in progress):

```ruby
class OtherAction < CleanActions::Base
  def perform_actions
    SyncData.call
  end
end

OtherAction.call # => "SyncData#before_transaction was called inside the transaction"  is logged
```

### before_actions

If you want to do something before action — use `#before_action` callback, that is run inside the transaction but before `#perform_actions`:

```ruby
class AddItemToCart < CleanActions::Base
  def before_actions
    @order = Order.find(order_id)
  end

  def perform_actions
    # use order
  end
end
```

### fail_with

Fail with is a syntax sugar over `#fail!` to decouple pre–checks from the execution logic. Take a look at the improved example from the [Error Handling](/README.md#Error-Handling) section:

```ruby
class AddItemToCart < CleanActions::Base
  fail_with(:shop_is_closed) { Time.now.hour.in?(10..18) }

  def perform_actions
    # only when shop is open
  end
end
```

If you want to check that action can be called successfully (at least, preconditions are met) — you can use `#dry_call`, which will run _all_ preconditions and return all failures:

```ruby
class CheckNumber < CleanActions::Base
  fail_with(:fail1) { @value == 1 }
  fail_with(:fail_odd) { @value.odd? }

  def initialize(value:)
    @value = value
  end
end

CheckNumber.dry_call(value: 1) # => [CleanActions::ActionFailure.new(:fail_odd), CleanActions::ActionFailure.new(:fail1)]
```

### rollback

Actions rollback things inside `#perform_actions` in case of failure because of the database transactions. However, what if you want to rollback something non–transactional?

Well, if you sent an email or enqueued background job—you cannot do much,. Just in case, you want do something—here is a `#rollback` method that happens only when action fails.

```ruby
class DumbCounter < CleanActions::Base
  def perform_actions
    Thread.current[:counter] ||= 0
    Thread.current[:counter] += 1
    fail!(:didnt_i_say_its_a_dumb_counter)
  end

  def rollback
    Thread.current[:counter] ||= 0
    Thread.current[:counter] -= 1
  end
end

DumbCounter.call
Thread.current[:counter] # => 0
```

### ensure

Opened file inside `#perform_actions` or want to do some other cleanup even when action fails? Use `#ensure`:

```ruby
class UseFile < CleanActions::Base
  def perform_actions
    @file = File.open # ...
  end

  def ensure
    @file.close
  end
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/DmitryTsepelev/clean_actions.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
