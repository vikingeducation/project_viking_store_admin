class UsersController < ApplicationController
  def index
    @users = User.all
  end

  def show
    @user = User.find(params[:id])
    @orders = @user.orders
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(whitelisted_params)
    if @user.save
      flash[:success] = "You just created a new user"
      redirect_to @user
    else
      flash.now[:danger] = "Something went wrong"
      render :new
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    if @user.update(whitelisted_params)
      flash[:success]= "You succesfully update the user"
      redirect_to @user
    else
      flash.now[:danger]= "Something went wrong"
      render :edit
    end
  end

  private
  def whitelisted_params
    params.require(:user).permit(:first_name, :last_name, :email)
  end
end 
