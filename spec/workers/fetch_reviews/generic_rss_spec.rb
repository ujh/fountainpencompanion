require "rails_helper"

describe FetchReviews::GenericRss do
  it "refuses to follow a feed redirect to an internal address" do
    allow(Resolv).to receive(:getaddresses).with("feed.test").and_return(["93.184.216.34"])
    allow(Resolv).to receive(:getaddresses).with("internal.test").and_return(["10.0.0.7"])
    stub_request(:get, "https://feed.test/rss").to_return(
      status: 302,
      headers: {
        "Location" => "http://internal.test/"
      }
    )

    expect { described_class.new.perform("https://feed.test/rss") }.to raise_error(
      SafeHttp::BlockedError
    )
  end

  it "creates web pages for the feed items" do
    allow(Resolv).to receive(:getaddresses).with("feed.test").and_return(["93.184.216.34"])
    stub_request(:get, "https://feed.test/rss").to_return(status: 200, body: <<~XML)
      <?xml version="1.0"?>
      <rss version="2.0"><channel><title>t</title><link>https://feed.test</link><description>d</description>
        <item><title>Pilot Kon-peki</title><link>https://feed.test/kon-peki</link></item>
      </channel></rss>
    XML

    described_class.new.perform("https://feed.test/rss")

    expect(WebPageForReview.pluck(:url)).to eq(["https://feed.test/kon-peki"])
  end
end
