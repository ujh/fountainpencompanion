class BlogController < ApplicationController
  def index
    @posts = BlogPost.published.order('published_at desc').page(params[:page])
  end

  def show
    @post = BlogPost.published.find(params[:id])
  end

  def feed
    @posts = BlogPost.order('published_at desc')
    render layout: false
  end
end
