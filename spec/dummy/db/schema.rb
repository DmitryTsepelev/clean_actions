# frozen_string_literal: true

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :users, force: true do |t|
    t.boolean :banned, null: false, default: false
    t.timestamps null: false
  end

  create_table :orders, force: true do |t|
    t.string :status, null: false, default: "cart"
    t.references :user
    t.timestamps null: false
  end

  create_table :order_items, force: true do |t|
    t.references :order
    t.references :item
    t.integer :quantity
    t.timestamps null: false
  end

  create_table :items, force: true do |t|
    t.string :name, null: false
    t.integer :in_stock, null: false
    t.timestamps null: false
  end
end
