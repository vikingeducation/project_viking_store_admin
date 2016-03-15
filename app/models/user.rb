class User < ActiveRecord::Base

  has_one :credit_card
  has_many :addresses
  has_many :orders

  def self.created_since_days_ago(number)
    User.all.where('created_at >= ?', number.days.ago).count
  end

  # Field: Highest single order value and the customer who achieved it
  # Tables needed:
    # users for user first_name and last_name
    # orders so that I can make sure that the order was actually ordered via checkout_date
    # order_contents so that I can see which orders had which product_ids and quantity
    # products so that I can see see what those products prices are.
  # First I connect orders and order_contents so that we can filter our all the order_contents that haven't been checked out yet
  # Order.find_by_sql("SELECT * FROM orders JOIN order_contents ON orders.id=order_contents.order_id WHERE orders.checkout_date IS NOT NULL")
  # Now I need to join on products so that i can make an extra column which multiplies order_contents.quantity by products.price
  # Order.find_by_sql("SELECT *, (order_contents.quantity * products.price) as sub FROM orders JOIN order_contents ON orders.id=order_contents.order_id JOIN products ON order_contents.product_id=products.id WHERE orders.checkout_date IS NOT NULL")
  # Next I gotta group by the order_id and get the total of sub
  # This gets me a table with the order_id and the total cost of each one
  # I've also ordered it descending on the total and limited it to 1 result.
  # a = Order.find_by_sql("SELECT order_contents.order_id, SUM(order_contents.quantity * products.price) as total FROM orders JOIN order_contents ON orders.id=order_contents.order_id JOIN products ON order_contents.product_id=products.id WHERE orders.checkout_date IS NOT NULL GROUP BY order_contents.order_id ORDER BY total DESC LIMIT 1")
  # Making this a subquery and joining orders and users tables to it.

  def self.biggest_order
    User.find_by_sql("SELECT * FROM orders JOIN (SELECT order_contents.order_id, SUM(order_contents.quantity * products.price) as total FROM orders JOIN order_contents ON orders.id=order_contents.order_id JOIN products ON order_contents.product_id=products.id WHERE orders.checkout_date IS NOT NULL GROUP BY order_contents.order_id ORDER BY total DESC LIMIT 1) AS sub ON orders.id = sub.order_id JOIN users ON orders.user_id=users.id")
  end

  # Field: Highest Lifetime value customer (by total revenue generated)

  # Field: Highest average order value and the customer who placed it

  # Field: Most orders placed and the customer who placed it
end
