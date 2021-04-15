namespace :clean_up do

  desc "Run all clean up tasks"
  task all: [:unused_accounts, :unconfirmed_accounts]

  desc "Remove users that haven't logged in for over two years"
  task unused_accounts: :environment do
    cutoff = 2.years.ago
    User.where('current_sign_in_at < ?', cutoff).destroy_all
    User.where(current_sign_in_at: nil).where('created_at < ?', cutoff).destroy_all
  end

  desc "Remove users that haven't confirmed their email in 4 weeks"
  task unconfirmed_accounts: :environment do
    User.where(confirmed_at: nil).where('created_at < ?', 40.weeks.ago).destroy_all
  end
end
