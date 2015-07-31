class UsersController < ApplicationController

  before_action :require_current_user, :exclude => [:new, :create]

  def new
    @user = User.new
    @user.created_addresses.build
  end


  def create
    @user = User.new(user_params)
    if @user.save
      sign_in @user
      flash[:success] = "Welcome!"
      redirect_to products_path
    else
      flash.now[:danger] = "Error! Please try again."
      render :new
    end
  end


  def edit
    @user = current_user
    @user.created_addresses.build
  end


  def update
    if current_user.update(user_params)
      flash[:success] = "Update successful!"
      redirect_to products_path
    else
      flash.now[:danger] = "Error!  Updates not saved!"
      @user = current_user
      render :edit
    end
  end


  def destroy
    current_user.destroy!
    sign_out
    redirect_to new_session_path
  end



  private


  def user_params
    params.
      require(:user).
      permit( :email,
              :email_confirmation,
              :first_name,
              :last_name,
              :shipping_id,
              :billing_id,
              #:addresses_ids,
              { :created_addresses_attributes => [
                  :street_address,
                  :city_id,
                  :state_id,
                  :zip_code,
                  :user_id ] } )
  end


  def require_current_user
    unless current_user == User.find(params[:id])
      flash[:error] = "Access denied!!!"
      redirect_to new_session_path
    end
  end

end
