class Order < ActiveRecord::Base
  attr_accessor :toggle


  belongs_to :user
  has_many :order_contents, dependent: :destroy
  has_many :products, -> { select("products.*, order_contents.quantity AS quantity,
                                   (order_contents.quantity * products.price) AS total_price") }, 
                      through: :order_contents
  has_many :categories, through: :products
  belongs_to :billing_address, foreign_key: :billing_id, class_name: "Address"
  belongs_to :shipping_address, foreign_key: :shipping_id, class_name: "Address"
  belongs_to :credit_card

  accepts_nested_attributes_for :order_contents, allow_destroy: true,
  reject_if: proc { |attributes| attributes['product_id'].blank? }

  validates :shipping_id, :billing_id, :credit_card_id, presence: true
  validate :users_details

  before_update :toggle_order_status?
  


  # def combine_products
  #   p_ids = order_contents.pluck(:product_id)

  #   if p_ids.uniq!

  #     p_ids.uniq.each do |p_id|
  #       if (p_ids.select { |n| p_id = n}).length > 1
  #         duplicates = order_contents.where("product_id = ?", p_id)
  #         total_quantity = duplicates.pluck(:quantity).sum
  #         combined = order_contents.build(product_id: p_id,
  #                                         quantity: total_quantity)
  #         duplicates.destroy
  #         combined.save
  #       end 
  #     end

  #   end
  # end


  def value
    products.inject(0) { |sum, p| sum += p.total_price }
  end


  def self.submitted_count(period = nil)
    submitted = Order.submitted
    if period 
      submitted = submitted.checkout_date_rage(period)
    end
    submitted.count
  end


  def self.total_revenue(period = nil)
    total = Order.select("SUM(products.price) AS t").join_with_products.submitted
    if period
      total = total.checkout_date_rage(period)
    end
    total.to_a.first.t
  end


  def self.most_expensive_order
    o = Order.joins("JOIN (#{Order.order_totals.to_sql}) order_totals ON order_totals.id = orders.id").
              select("orders.user_id, order_value").order("order_value DESC").limit(1)
    User.select("users.first_name, users.last_name, order_value AS value").
         joins("JOIN (#{o.to_sql}) o ON o.user_id = users.id").first
  end


  def self.highest_lifetime_value
    o = Order.select("Orders.user_id, SUM(products.price) AS all_orders_value").
             join_with_products.submitted.group("orders.user_id").
             order("all_orders_value DESC").limit(1)
    User.select("users.first_name, users.last_name, all_orders_value AS value").
         joins("JOIN (#{o.to_sql}) o ON o.user_id = users.id").first
  end


  def self.highest_average_order
    o = Order.joins("JOIN (#{Order.order_totals.to_sql}) order_totals ON order_totals.id = orders.id").
              select("orders.user_id, AVG(order_totals.order_value) as average_order_value").
              group("user_id").order("average_order_value DESC").limit(1)
    User.select("users.first_name, users.last_name, average_order_value AS value").
         joins("JOIN (#{o.to_sql}) o ON o.user_id = users.id").first
  end


  def self.most_orders_placed
    o = Order.select("orders.user_id, COUNT(*) as ocount").
              group("orders.user_id").order("ocount DESC").limit(1)
    User.select("users.first_name, users.last_name, ocount AS value").
         joins("JOIN (#{o.to_sql}) o ON o.user_id = users.id").first
  end


  def self.average_order_value(period = nil)
    avg = Order.select("ROUND(AVG(totals.order_value),2) as order_avg").
                joins("JOIN (#{Order.order_totals.to_sql}) totals ON totals.id = orders.id")
    if period
      avg = avg.checkout_date_rage(period)
    end
    avg.to_a.first.order_avg
  end


  def self.largest_order_value(period = nil)
    max = Order.select("MAX(totals.order_value) as order_max").
                joins("JOIN (#{Order.order_totals.to_sql}) totals ON totals.id = orders.id")
    if period
      max = max.checkout_date_rage(period)
    end
    max.to_a.first.order_max
  end


  def self.orders_by_day(days)
    Order.orders_by_time_period(:day, days)
  end


  def self.orders_by_week(weeks)
    Order.orders_by_time_period(:week, weeks)
  end


  private


  def toggle_order_status?
    if toggle == "placed" && checkout_date.nil?
      self.checkout_date = DateTime.now
    elsif toggle == "unplaced" 
      if new_cart_allowed?
        self.checkout_date = nil
      else
        errors.add(:base, "This user already has one unplaced order!")
        false
      end
    end 
  end


  def new_cart_allowed?
    !User.find(self.user_id).orders.where("checkout_date IS NULL").exists?
  end


  def users_details
    errors.add(:billing_id, "is invalid") unless user.address_ids.include?(self.billing_id)
    errors.add(:shipping_id, "is invalid") unless user.address_ids.include?(self.shipping_id)
    errors.add(:credit_card_id, "is invalid") unless user.credit_card_ids.include?(self.credit_card_id)
  end


  def self.orders_by_time_period(time_period, limit)
    totals = Order.select("*").joins("JOIN (#{Order.order_totals.to_sql}) t ON t.id = orders.id")

    Order.select("DATE(intervals) AS #{time_period}, COALESCE(COUNT(totals.*), 0) AS num_orders, 
                  COALESCE(SUM(totals.order_value), 0) AS revenue").
          from("GENERATE_SERIES(( SELECT DATE(DATE_TRUNC('#{time_period}', MIN(checkout_date))) FROM orders),
                CURRENT_DATE, '1 #{time_period}'::INTERVAL) intervals").
          joins("LEFT JOIN (#{totals.to_sql}) totals ON DATE(DATE_TRUNC('#{time_period}', 
                 totals.checkout_date)) = intervals").
          group("intervals").order("intervals DESC").limit(limit)
  end


  def self.checkout_date_rage(period)
    where( "checkout_date BETWEEN :start AND :finish",
         { start: DateTime.now - period, finish: DateTime.now } )
  end


  def self.order_totals
    Order.select("orders.id, SUM(products.price) AS order_value").
          join_with_products.submitted.group("orders.id")
  end


  def self.submitted
    where("checkout_date IS NOT NULL")
  end


  def self.cart
    where("checkout_date IS NULL")
  end


  def self.join_with_products
    join_with_order_contents.join_order_contents_with_products
  end


  def self.join_with_order_contents
    joins("JOIN order_contents ON orders.id = order_contents.order_id ")
  end


  def self.join_order_contents_with_products
    joins("JOIN products ON order_contents.product_id = products.id")
  end



end
