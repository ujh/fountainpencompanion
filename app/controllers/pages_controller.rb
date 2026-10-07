class PagesController < ApplicationController
  PAGES = %w[
    bottles_leaderboard
    brands_leaderboard
    cartridges_leaderboard
    cookies
    currently_inked_leaderboard
    donate
    faq
    guide
    home
    ink_review_submissions_leaderboard
    inks_by_popularity
    inks_leaderboard
    leaderboards
    legal
    pens_by_popularity
    privacy-policy
    samples_leaderboard
    usage_records_leaderboard
    users_by_description_edits_leaderboard
  ].freeze

  def show
    unless PAGES.include?(params[:id])
      return render file: "public/404.html", status: :not_found, layout: false
    end

    if user_signed_in? && params[:id] == "home"
      redirect_to(dashboard_path)
    else
      render template: "pages/#{params[:id]}"
    end
  end
end
