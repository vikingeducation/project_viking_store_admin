class Product < ActiveRecord::Base

  def self.total_products
    count
  end

  def self.day_products_total(day)
    where("updated_at > ? ", day.days.ago).count
  end
end
