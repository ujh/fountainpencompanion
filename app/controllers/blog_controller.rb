class BlogController < ApplicationController
  add_breadcrumb "Blog", "/blog"

  def index
    @posts = BlogPost.published.order("published_at desc").page(params[:page])
  end

  def show
    @post = BlogPost.published.find(params[:id])

    add_breadcrumb "#{@post.title}", blog_path(@post)

    if user_signed_in?
      @post.reading_statuses.find_by(user: current_user)&.update(read: true, dismissed: false)
    end
  end

  def feed
    @posts = BlogPost.published.order("published_at desc")
    render layout: false
  end
end
