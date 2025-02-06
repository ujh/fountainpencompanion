class UsersController < ApplicationController
  add_breadcrumb "Users", "/users"

  def index
    @users = User.public.order("lower(name), id")
  end

  def show
    @user = User.where(spam: false).find(params[:id])

    add_breadcrumb "#{@user.name}", user_path(@user)

    respond_to do |format|
      format.html
      format.jsonapi do
        render jsonapi: @user,
               include: :collected_inks,
               fields: {
                 collected_inks: %i[brand_name line_name ink_name maker kind color comment ink_id]
               }
      end
    end
  end
end
