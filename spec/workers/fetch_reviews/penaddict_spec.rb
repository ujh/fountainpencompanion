require 'rails_helper'

describe FetchReviews::PenAddict do
  before do
    stub_request(:get, 'https://penaddict.com/blog?format=rss').to_return(
      body: file_fixture("penaddict.rss")
    )
  end

  it 'adds all items as ink reviews' do
    expect do
      FetchReviews::PenAddict.new.perform
      # 20 items in total minus 5 giveaway posts
    end.to change(FetchReviews::SubmitReview.jobs, :count).by(15)
  end
end
