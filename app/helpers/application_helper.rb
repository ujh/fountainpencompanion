module ApplicationHelper
  def patron_tiny(user)
    title = "Supports this site with a monthly subscription through Patreon."
    if user.patron?
      image_tag("patreon.png", class: "fpc-patron-tiny", title: title)
    end
  end

  def leaderboard_patron_tiny(data)
    title = "Supports this site with a monthly subscription through Patreon."
    if data[:patron]
      image_tag("patreon.png", class: "fpc-patron-tiny", title: title)
    end
  end

  def show_fundraiser?
    # Only for signed in users, roughly every 8 weeks
    user_signed_in? && !current_user.patron? && (Date.current.cweek % 8).zero?
  end

  def admin?
    current_user&.admin? || admin_signed_in?
  end
end
