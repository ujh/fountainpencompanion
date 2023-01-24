unless User.find_by(email: "urban@bettong.net")
  user = User.new(email: "urban@bettong.net")
  user.password = user.password_confirmation = SecureRandom.hex
  user.save!
end

unless Admin.find_by(email: "urban@bettong.net")
  admin = Admin.new(email: "urban@bettong.net")
  admin.password = admin.password_confirmation = SecureRandom.hex
  admin.save!
end
