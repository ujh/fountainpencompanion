unless User.find_by(email: "urban@bettong.net")
  user = User.new(email: "urban@bettong.net")
  user.password = user.password_confirmation = SecureRandom.hex
  user.admin = true
  user.save!
end
