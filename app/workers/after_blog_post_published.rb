class AfterBlogPostPublished
  include Sidekiq::Worker

  def perform(id)
    blog_post = BlogPost.find(id)

    User.active.find_each do |user|
      AfterBlogPostPublishedForUser.perform_async(blog_post.id, user.id)
    end
  end
end
