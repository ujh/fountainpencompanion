class Admins::BlogPostsController < Admins::BaseController

  def index
    @blog_posts = BlogPost.order('published_at desc, created_at desc')
  end

  def new
    @blog_post = BlogPost.new
  end

  def create
    @blog_post = BlogPost.new(permitted_params)
    if @blog_post.save
      flash[:notice] = "Blog post successfully created"
      redirect_to admins_blog_posts_path
    else
      render :new
    end
  end

  def edit
    @blog_post = BlogPost.find(params[:id])
  end

  def update
    @blog_post = BlogPost.find(params[:id])
    if @blog_post.update(permitted_params)
      flash[:notice] = "Blog post successfully updated"
      redirect_to admins_blog_posts_path
    else
      render :edit
    end
  end

  def destroy
    @blog_post = BlogPost.find(params[:id])
    @blog_post.destroy!
    flash[:notice] = "blog post successfully deleted"
    redirect_to admins_blog_posts_path
  end

  def publish
    @blog_post = BlogPost.find(params[:id])
    @blog_post.touch(:published_at)
    flash[:notice] = "Blog post successfully published"
    redirect_to admins_blog_posts_path
  end

  private

  def permitted_params
    params.require(:blog_post).permit(:title, :body, :published_at)
  end
end
