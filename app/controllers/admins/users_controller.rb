require 'csv'

class Admins::UsersController < Admins::BaseController

  before_action :fetch_user, only: [:become, :import]

  def index
    @users = User.order(:id)
  end

  def become
    sign_in(:user, @user, bypass: true)
    redirect_to root_url
  end

  def import
    count = 0
    CSV.parse(params[:file].read, headers: true) do |row|
      row = row.to_hash
      row.keys.each {|k|
        row[k] = '' if row[k].nil?
        row[k] = row[k].strip
      }
      row["private"] = !row["private"].blank?
      ci = @user.collected_inks.build
      ink_params = row.slice(
        "brand_name", "line_name", "ink_name", "kind", "private", "comment"
      )
      SaveCollectedInk.new(ci, ink_params).perform
      count +=1 if ci.persisted?
    end
    flash[:notice] = "#{count} inks imported for #{@user.email}"
    redirect_to admins_users_path
  end

  private

  def fetch_user
    @user = User.find(params[:id])
  end
end
