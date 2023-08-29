class Order < ApplicationRecord
  has_many :order_items
end
