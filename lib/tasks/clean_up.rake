namespace :clean_up do

  desc "Run all clean up tasks"
  task all: [:unused_accounts, :unconfirmed_accounts]

  desc "Remove users that haven't never logged in in two years"
  task unused_accounts: :environment do
    User.where(current_sign_in_at: nil).where('created_at < ?', 2.years.ago).destroy_all
  end

  desc "Remove users that haven't confirmed their email in 2 months"
  task unconfirmed_accounts: :environment do
    User.where(confirmed_at: nil).where('created_at < ?', 2.months.ago).destroy_all
  end
end
