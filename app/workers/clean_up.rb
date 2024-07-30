class CleanUp
  include Sidekiq::Worker

  def perform
    remove_unused_accounts
    remove_unconfirmed_accounts
    remove_spam_accounts
    anonymize_sign_up_ip
  end

  private

  # Remove users that have never logged in and created their account more than two years ago
  def remove_unused_accounts
    User
      .where(current_sign_in_at: nil)
      .where("created_at < ?", 2.years.ago)
      .destroy_all
  end

  # Remove users that haven't confirmed their email in 4 weeks
  def remove_unconfirmed_accounts
    User
      .where(confirmed_at: nil)
      .where("created_at < ?", 4.weeks.ago)
      .destroy_all
  end

  def anonymize_sign_up_ip
    User.where("created_at < ?", 1.month.ago).update_all(sign_up_ip: nil)
  end

  def remove_spam_accounts
    spammers =
      User.where.not(blurb: "").find_all { |u| u.blurb.scan("http").count > 4 }
    spammers.destroy_all
  end
end
