require "csv"

class Admins::UsersController < Admins::BaseController
  before_action :fetch_user,
                only: %i[
                  become
                  ink_import
                  pen_import
                  currently_inked_import
                  show
                  update
                ]

  def index
    @users = User.active.order(:id)
    @ink_counts =
      CollectedInk
        .group(:user_id)
        .select("user_id, count(id)")
        .reduce({}) do |acc, el|
          acc[el.user_id] = el.count
          acc
        end
    @pen_counts =
      CollectedPen
        .group(:user_id)
        .select("user_id, count(id)")
        .reduce({}) do |acc, el|
          acc[el.user_id] = el.count
          acc
        end
    @ci_counts =
      CurrentlyInked
        .group(:user_id)
        .select("user_id, max(inked_on) as inked_on, count(id)")
        .reduce({}) do |acc, el|
          acc[el.user_id] = el.count
          acc
        end
  end

  def show
  end

  def update
    if @user.update(params.require(:user).permit(:patron))
      redirect_to admins_user_path(@user)
    else
      render :show
    end
  end

  def become
    sign_in(:user, @user, bypass: true)
    redirect_to root_url
  end

  def ink_import
    count = 0
    content = params[:file].read.force_encoding("UTF-8")
    CSV.parse(content, headers: true) do |row|
      row = row.to_hash
      ImportCollectedInk.perform_async(@user.id, row)
      count += 1
    end
    flash[:notice] = "#{count} inks scheduled for import for #{@user.email}"
    redirect_to admins_users_path
  end

  def pen_import
    count = 0
    content = params[:file].read.force_encoding("UTF-8")
    CSV.parse(content, headers: true) do |row|
      row = row.to_hash
      ImportCollectedPen.perform_async(@user.id, row)
      count += 1
    end
    flash[:notice] = "#{count} pens scheduled for import for #{@user.email}"
    redirect_to admins_users_path
  end

  def currently_inked_import
    count = 0
    content = params[:file].read.force_encoding("UTF-8")
    CSV.parse(content, headers: true) do |row|
      row = row.to_hash
      ImportCurrentlyInked.perform_async(@user.id, row)
      count += 1
    end
    flash[
      :notice
    ] = "#{count} currently inked entries scheduled for import for #{@user.email}"
    redirect_to admins_users_path
  end

  private

  def fetch_user
    @user = User.find(params[:id])
  end
end
