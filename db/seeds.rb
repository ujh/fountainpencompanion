return unless Rails.env.development?

user = User.find_or_initialize_by(email: "urban@bettong.net")
user.password = user.password_confirmation = "password"
user.admin = true
user.confirmed_at = Time.now
user.save
