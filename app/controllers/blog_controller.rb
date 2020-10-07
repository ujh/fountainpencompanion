class BlogController < ApplicationController
  def index
    @posts = BlogPost.published.order('published_at desc').page(params[:page])
  end

  def show
    @post = BlogPost.published.find(params[:id])
    if user_signed_in?
      @post.reading_statuses.find_by(user: current_user)&.update(read: true)
    end
  end

  def feed
    @posts = BlogPost.published.order('published_at desc')
    render layout: false
  end
end
