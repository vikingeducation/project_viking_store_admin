class State < ApplicationRecord
  def self.three_with_most_users
    joins("INNER JOIN addresses ON states.id = addresses.state_id").
      joins("INNER JOIN users ON users.billing_id = addresses.id").
      group("states.name").
      order("count_states_id DESC").
      limit(3).
      count("states.id")
  end
end
