class AfterUserSaved
  include Sidekiq::Worker

  def perform(user_id)
    self.user = User.find_by(id: user_id)
    check_user!
  end

  private

  attr_accessor :user

  def check_user!
    markdown = FpcFormatter.render(user.blurb)
    found_link = markdown.include?("http") || markdown.include?("<a ")
    user.update(review_blurb: found_link)
    ClassifyUser.perform_async(user.id) if found_link
  end
end
