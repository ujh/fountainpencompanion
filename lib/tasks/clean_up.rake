namespace :clean_up do

  desc "Run all clean up tasks"
  task all: [:users]

  desc "Remove users that haven't logged in for over two years"
  task users: :environment do
    User.where('current_sign_in_at < ?', 2.years.ago).destroy_all
    User.where(confirmed_at: nil).where('created_at < ?', 2.weeks.ago).destroy_all
  end
end
