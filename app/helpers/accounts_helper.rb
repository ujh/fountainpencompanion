module AccountsHelper

  def profile_image(size: 500)
    image_tag(profile_image_url(size: size))
  end

  def profile_image_url(size:)
    hash = Digest::MD5.hexdigest(current_user.email.downcase)
    "https://www.gravatar.com/avatar/#{hash}.jpg?s=#{size}"
  end

end
