class AfterBlogPostPublished
  include Sidekiq::Worker

  def perform(id)
    blog_post = BlogPost.find(id)
    User.active.find_each do |user|
      user.reading_statuses.create!(blog_post: blog_post)
    end
  end
end
