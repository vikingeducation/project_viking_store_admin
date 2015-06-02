class OrdersController < ApplicationController
  layout "admin"

  def index
    @orders = Order.user_order(params[:user_id])
  end

  def new
    @order = Order.new
    @user = User.find(params[:user_id])
  end

  def create
    @order = Order.new(whitelisted_order_params)
    if @order.save
      flash[:success] = "Order addresses confirmed!"
      redirect_to edit_order_path(@order.id)
    else
      flash[:error] = @order.errors.full_messages.to_sentence
      render "/orders/new"
    end
  end

  def show
    @order = Order.find(params[:id])
  end

  def whitelisted_order_params
    params.require(:order).permit(:user_id, :shipping_id, :billing_id)
  end
end
