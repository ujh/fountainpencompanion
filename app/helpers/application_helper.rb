module ApplicationHelper
  def patron_tiny(user)
    title = "Supports this site with a monthly subscription through Patreon."
    image_pack_tag("patreon.png", class: 'patron-tiny', title: title) if user.patron?
  end

  def leaderboard_patron_tiny(data)
    title = "Supports this site with a monthly subscription through Patreon."
    image_pack_tag("patreon.png", class: 'patron-tiny', title: title) if data[:patron]
  end

  def show_fundraiser?
    # Only for signed in users, every 6 months
    user_signed_in? && !current_user.patron? && [17, 43].include?(Date.current.cweek)
  end
end
