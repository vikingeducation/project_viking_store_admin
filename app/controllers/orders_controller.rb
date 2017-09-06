class OrdersController < ApplicationController
  def index
    if params[:user_id]
      if User.exists?(params[:user_id])
        @user = User.find(params[:user_id])
        @orders = Order.where(user_id: params[:user_id])
      else
        flash.now[:error] = "Invalid User ID provided. Displaying all Orders."
        @orders = Order.all
      end
    else
      @orders = Order.all
    end

    render layout: "admin_portal"
  end

  def show
    @order = Order.find(params[:id])
    @user = @order.user
    @products_in_order = @order.products
    @order_line_items = @order.line_items

    render layout: "admin_portal"
  end
end
