require "rails_helper"

RSpec.describe Unfurler::Youtube::Comments do
  let(:video_id) { "abc123" }
  let(:client) { double(:client) }
  subject(:fetcher) { described_class.new(video_id, client: client) }

  def make_thread(author:, text:, like_count: 0)
    snippet =
      double(:snippet, author_display_name: author, text_display: text, like_count: like_count)
    top_level = double(:top_level_comment, snippet: snippet)
    thread_snippet = double(:thread_snippet, top_level_comment: top_level)
    double(:thread, snippet: thread_snippet)
  end

  it "maps each thread to author/text/like_count" do
    response =
      double(
        :response,
        items: [
          make_thread(author: "Alice", text: "Great review!", like_count: 5),
          make_thread(author: "Bob", text: "Which nib?", like_count: 2)
        ]
      )
    expect(client).to receive(:list_comment_threads).with(
      "snippet",
      video_id: video_id,
      order: "relevance",
      max_results: 10
    ).and_return(response)

    result = fetcher.fetch

    expect(result).to eq(
      [
        { author: "Alice", text: "Great review!", like_count: 5 },
        { author: "Bob", text: "Which nib?", like_count: 2 }
      ]
    )
  end

  it "returns an empty array when comments are disabled" do
    allow(client).to receive(:list_comment_threads).and_raise(
      Google::Apis::ClientError.new("commentsDisabled: Comments are disabled.")
    )
    expect(fetcher.fetch).to eq([])
  end

  it "re-raises generic forbidden errors so auth/quota issues surface" do
    allow(client).to receive(:list_comment_threads).and_raise(
      Google::Apis::ClientError.new("forbidden")
    )
    expect { fetcher.fetch }.to raise_error(Google::Apis::ClientError)
  end

  it "re-raises other client errors" do
    allow(client).to receive(:list_comment_threads).and_raise(
      Google::Apis::ClientError.new("quotaExceeded")
    )
    expect { fetcher.fetch }.to raise_error(Google::Apis::ClientError)
  end

  it "returns an empty array when the API returns no items" do
    allow(client).to receive(:list_comment_threads).and_return(double(:response, items: nil))
    expect(fetcher.fetch).to eq([])
  end
end
