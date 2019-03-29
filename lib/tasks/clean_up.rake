namespace :clean_up do

  desc "Run all clean up tasks"
  task all: [:users, :clusters]

  desc "Clean up empty ink and brand clusters"
  task clusters: :environment do
    NewInkName.empty.destroy_all
    InkBrand.empty.destroy_all
  end

  desc "Remove users that haven't logged in for over two years"
  task users: :environment do
    User.where('current_sign_in_at < ?', 2.years.ago).destroy_all
  end
end
