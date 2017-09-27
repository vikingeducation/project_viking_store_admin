class Order < ApplicationRecord
  validates :user_id,
            :shipping_id,
            :billing_id,
            :credit_card_id,
            presence: true

  # An Order has an associated User and CreditCard.
  belongs_to :user
  belongs_to :credit_card

  # An Order has an associated billing and shipping Address.
  belongs_to :billing_address, class_name: "Address", foreign_key: :billing_id
  belongs_to :shipping_address, class_name: "Address", foreign_key: :shipping_id

  # An Order can have many Products through OrderContents.
  # If an Order is destroyed, we should also destroy all associated rows in OrderContents.
  has_many :order_contents, dependent: :destroy
  has_many :products, through: :order_contents

  # An Order can have many Categories through its associated Products.
  has_many :categories, through: :products, source: :category



  private

  def show_order_base_query
    Order
    .joins("JOIN order_contents ON orders.id = order_contents.order_id")
    .joins("JOIN products ON products.id = order_contents.product_id")
    .where("orders.id = ?", self.id)
  end


  public

  # calculates the value of an Order
  def value
    if show_order_base_query.present?
      show_order_base_query
      .select("SUM(order_contents.quantity * products.price) AS amount")
      .group("orders.id")
      .first
      .amount
    else
      0
    end
  end

  # checks if an Order has been placed
  def placed?
    !self.checkout_date.nil?
  end

  # checks if an Order is actually a shopping cart
  def is_shopping_cart?
    self.checkout_date.nil?
  end

  # returns HTML elements depicting the status of an Order:
  # "UNPLACED" if Order is a shopping cart,
  # "PLACED" if Order has a checkout_date
  def status
    if self.is_shopping_cart?
      '<span class="text-danger">UNPLACED</span>'.html_safe
    else
      '<span class="text-success">PLACED</span>'.html_safe
    end
  end

  # returns the line items of an Order - which products were in the
  # Order, along with quantity and price of each Product
  def line_items
    show_order_base_query
    .order("order_contents.quantity DESC")
    .select("order_contents.id, order_contents.order_id, order_contents.product_id, products.name, products.price, order_contents.quantity, products.price * order_contents.quantity AS total_price")
  end



  ##### TODO: Methods for Analytics Dashboard to be refactored #####

  ########## Methods for Orders ##########

  # finds the number of new Orders that were placed within a number of days from the current day
  def self.orders_within(days)
    Order
    .where("checkout_date IS NOT NULL")
    .where("created_at >= ?", Time.now - days.days)
    .count
  end

  # finds the total number of Orders placed across all time
  def self.total_orders
    Order.where("checkout_date IS NOT NULL").count
  end

  # finds the value of the largest Order within a number of days from the current day
  def self.largest_order_value_within(days)
    largest_order = self.revenue_per_order
                    .where("orders.created_at >= ?", Time.now - days.days)
                    .order("revenue DESC")
                    .limit(1)
                    .first

    largest_order ? largest_order.revenue : 0
  end

  # finds the value of the largest Order across all time
  def self.largest_order_value_across_all_time
    self.revenue_per_order
    .order("revenue DESC")
    .limit(1)
    .first
    .revenue
  end

  # determines the average Order value within a number of days from the current day
  def self.average_order_value_within(days)
    num_orders = self.orders_within(days)

    num_orders == 0 ? 0 : self.revenue_within(days) / self.orders_within(days)
  end

  # determines the average Order value across all time
  def self.average_order_value_across_all_time
    self.total_revenue / self.total_orders
  end

  ########## Methods for revenue ##########

  def self.base_revenue_query
    OrderContent
    .joins("JOIN orders ON orders.id = order_contents.order_id")
    .joins("JOIN products ON products.id = order_contents.product_id")
    .where("orders.checkout_date IS NOT NULL")
  end

  # calculates the total revenue across all time
  def self.total_revenue
    self.base_revenue_query
    .sum("order_contents.quantity * products.price")
  end

  # calculates the total revenue within a number of days from the current day
  def self.revenue_within(days)
    self.base_revenue_query
    .where("order_contents.created_at >= ?", Time.now - days.days)
    .sum("order_contents.quantity * products.price")
  end

  # calculates the revenue per Order.
  def self.revenue_per_order
    self.base_revenue_query
    .joins("JOIN users ON orders.user_id = users.id")
    .select("orders.id, users.first_name, users.last_name, SUM(order_contents.quantity * products.price) AS revenue")
    .group("orders.id, users.first_name, users.last_name")
  end

  # calculates the total revenue for each User.
  def self.revenue_per_user
    self.base_revenue_query
    .joins("JOIN users ON orders.user_id = users.id")
    .select("users.id, users.first_name, users.last_name, SUM(order_contents.quantity * products.price) AS revenue")
    .group("users.id")
  end

  ########## methods to generate time series data ##########

  # calculates the number of Orders and their amount for the past 7 days
  def self.orders_by_day(num_days = 7)
    Order.find_by_sql(
      "
      SELECT DATE(dates) AS date,
      COUNT(orders.*) AS num_orders,
      COALESCE(SUM(order_contents.quantity * products.price), 0) AS amount
      FROM GENERATE_SERIES((
        SELECT DATE(MIN(orders.checkout_date)) FROM orders),
        CURRENT_DATE, '1 DAY'::INTERVAL) dates
      LEFT JOIN orders ON DATE(orders.checkout_date) = dates
      LEFT JOIN order_contents ON orders.id = order_contents.order_id
      LEFT JOIN products ON products.id = order_contents.product_id
      GROUP BY dates
      ORDER BY dates DESC;
      "
    )[0..num_days - 1]
  end

  # calculates the number of Orders and their amount for the past 7 weeks
  def self.orders_by_week(num_weeks = 7)
    Order.find_by_sql(
    "
    SELECT DATE(weeks) AS date,
    COUNT(orders.*) AS num_orders,
    COALESCE(SUM(order_contents.quantity * products.price), 0) AS amount
    FROM GENERATE_SERIES((
      SELECT DATE(DATE_TRUNC('WEEK', MIN(orders.checkout_date))) FROM orders),
      CURRENT_DATE, '1 WEEK'::INTERVAL) weeks
    LEFT JOIN orders ON DATE(DATE_TRUNC('WEEK', orders.checkout_date)) = weeks
    LEFT JOIN order_contents ON orders.id = order_contents.order_id
    LEFT JOIN products ON products.id = order_contents.product_id
    GROUP BY weeks
    ORDER BY weeks DESC;
    "
    )[0..num_weeks - 1]
  end

  # formats the date of an daily Order for display in our view
  def self.format_date(date)
    case date
    when Date.today
      "Today"
    when Date.yesterday
      "Yesterday"
    else
      date.strftime('%m/%d')
    end
  end

  # formats the Orders for display in our view
  def self.format_orders(orders)
    formatted_orders = []

    orders.each do |order|
      formatted_orders.push(
        {
          date: self.format_date(order.date),
          num_orders: order.num_orders,
          amount: order.amount
        }
      )
    end

    formatted_orders
  end
end
