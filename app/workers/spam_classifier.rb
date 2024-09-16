class SpamClassifier
  include Sidekiq::Worker

  def perform(user_id)
    self.user = User.find_by(id: user_id)
    classify!
  end

  private

  attr_accessor :user

  def classify!
    if spam?
      user.update(spam: true, spam_reason: "auto-spam")
    else
      user.update(spam: false, spam_reason: "auto-not-spam")
    end
  end

  def spam?
    Bots::SpamClassifier.new(user).run
  end
end
