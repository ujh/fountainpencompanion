module AccountsHelper

  def profile_image(user)
    image_tag(profile_image_url(user), size: "500x500")
  end

  def profile_image_url(user)
    hash = Digest::MD5.hexdigest(user.email.downcase)
    "https://www.gravatar.com/avatar/#{hash}.jpg?s=500"
  end

end
