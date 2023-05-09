namespace :clean_up do
  desc "Run all clean up tasks"
  task all: %i[unused_accounts unconfirmed_accounts anonymize_sign_up_ip]

  desc "Remove users that have never logged in and created their account more than two years ago"
  task unused_accounts: :environment do
    User
      .where(current_sign_in_at: nil)
      .where("created_at < ?", 2.years.ago)
      .destroy_all
  end

  desc "Remove users that haven't confirmed their email in 4 weeks"
  task unconfirmed_accounts: :environment do
    User
      .where(confirmed_at: nil)
      .where("created_at < ?", 4.weeks.ago)
      .destroy_all
  end

  # TODO: Sometimes this seems to catch real accounts that were just marked as bot in the
  #       beginning. Let's disable this deletion for now.
  # desc "Remove bot accounts that are 8 weeks old"
  # task old_bot_accounts: :environment do
  #   User.where(bot: true).where("created_at < ?", 8.weeks.ago).destroy_all
  # end

  desc "Anonymize IP addresses used for sign up"
  task anonymize_sign_up_ip: :environment do
    User.where("created_at < ?", 1.month.ago).update_all(sign_up_ip: nil)
  end
end
