class Admins::ReviewFeedsController < Admins::BaseController
  add_breadcrumb "Review feeds", :admins_review_feeds_path

  def index
    @empty = params[:empty] == "1"
    @state = params[:state] if !@empty && ReviewFeed::STATES.include?(params[:state])
    @review_feeds = filtered_feeds.order(:state, :host).to_a
    @page_counts = page_counts
    @review_counts = approved_review_counts
  end

  def new
    @review_feed = ReviewFeed.new
  end

  def create
    @review_feed =
      ReviewFeed.new(
        create_params.merge(state: "active", curated: true, back_catalog_imported: false)
      )
    if @review_feed.save
      redirect_to admins_review_feeds_path, notice: "Feed for #{@review_feed.host} created"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @review_feed = ReviewFeed.find(params[:id])
  end

  def update
    @review_feed = ReviewFeed.find(params[:id])
    if UpdateReviewFeed.new(@review_feed, update_params).perform
      redirect_to admins_review_feeds_path, notice: "Feed for #{@review_feed.host} updated"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def ignore
    change_state(enabled: false)
  end

  def enable
    change_state(enabled: true)
  end

  private

  def change_state(enabled:)
    review_feed = ReviewFeed.find(params[:id])
    if ChangeReviewFeedState.new(review_feed, enabled:).perform
      flash[:notice] = "Feed for #{review_feed.host} is now #{review_feed.state}"
    else
      flash[:alert] = review_feed.errors.full_messages.to_sentence
    end
    redirect_to admins_review_feeds_path(
                  state: params[:filter_state].presence,
                  empty: params[:filter_empty].presence
                )
  end

  def filtered_feeds
    if @empty
      ReviewFeed.stale_empty
    elsif @state
      ReviewFeed.where(state: @state)
    else
      ReviewFeed.all
    end
  end

  def page_counts
    WebPageForReview
      .where(review_feed_id: @review_feeds.map(&:id))
      .group(:review_feed_id, :state)
      .count
  end

  def approved_review_counts
    InkReview
      .approved
      .where(InkReview::NORMALIZED_HOST.in(@review_feeds.map(&:host)))
      .group(InkReview::NORMALIZED_HOST)
      .count
  end

  def create_params
    params.require(:review_feed).permit(:host, :feed_url)
  end

  def update_params
    params.require(:review_feed).permit(:feed_url, :curated)
  end
end
