module AccountsHelper

  def profile_image_for(user, size: 500)
    image_tag(profile_image_url(user, size: size))
  end

  def profile_image(size: 500)
    image_tag(profile_image_url(current_user, size: size))
  end

  def profile_image_url(user, size:)
    hash = Digest::MD5.hexdigest(user.email.downcase)
    "https://www.gravatar.com/avatar/#{hash}.jpg?s=#{size}"
  end

end
