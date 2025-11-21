class AfterBlogPostPublishedForUser
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker

  sidekiq_throttle concurrency: { limit: 2 }
  sidekiq_options queue: "low"

  def perform(blog_post_id, user_id)
    user = User.active.find_by(id: user_id)
    return unless user

    blog_post = BlogPost.find_by(id: blog_post_id)
    return unless blog_post

    user.reading_statuses.create!(blog_post: blog_post)
  end
end
