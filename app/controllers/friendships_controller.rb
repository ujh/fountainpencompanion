class FriendshipsController < ApplicationController
  before_action :authenticate_user!

  def create
    friendship =
      Friendship.new(
        sender: current_user,
        friend: User.find(params[:friend_id])
      )
    if friendship.save
      head :ok
    else
      head :bad_request
    end
  end

  def update
    friendship = current_user.friendship_with(params[:id])
    if friendship and friendship.friend == current_user
      friendship.update(approved: true) if params[:approved].present?
      head :ok
    else
      head :bad_request
    end
  end

  def destroy
    friendship = current_user.friendship_with(params[:id])
    if friendship and
         [friendship.sender, friendship.friend].include?(current_user)
      friendship.destroy
      head :ok
    else
      head :bad_request
    end
  end
end
