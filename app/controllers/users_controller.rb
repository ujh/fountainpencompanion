class UsersController < ApplicationController

  def index
    @users = User.active.order('lower(name), id')
  end

  def show
    @user = User.find(params[:id])
    respond_to do |format|
      format.html
      format.jsonapi {
        render jsonapi: @user, include: :collected_inks, fields: {
          collected_inks: [
            :brand_name,
            :line_name,
            :ink_name,
            :maker,
            :kind,
            :color,
            :comment,
            :ink_id,
          ]
        }
      }
    end
  end
end
