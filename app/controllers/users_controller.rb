class UsersController < ApplicationController

  layout 'front_facing'

  def create
    # The first problem is trying to figure out how I'm gonna get a city_id into this thing....
    # All the addresses keys are from 0 upwards which means we could iterate with a .times enumerator pretty easy
    params["user"]["addresses_attributes"].size.times do |x| 
      # This will return the city that was entered for the address with x as the key.
      # Now I want to run that through the City class method that returns an id.
      address = params["user"]["addresses_attributes"][x.to_s]
      city_id = City.name_to_id(address["city"])
      # Entering that into the address city_id
      address[:city_id] = city_id
    end
    @user = User.new(whitelisted_params)
    asdfa
  end

  def new
    @user = User.new
  end

  private

  def whitelisted_params

    # Hopefully i can just require and permit this now...
    params.require(:user).permit(:billing_id, :shipping_id, :email, :first_name, :last_name, :addresses_attributes => [:id, :street_address, :state_id, :zip_code, :city_id])
  end

end
