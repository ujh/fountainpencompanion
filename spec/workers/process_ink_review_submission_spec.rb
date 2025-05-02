require "rails_helper"

describe ProcessInkReviewSubmission do
  let(:ink_review_submission) { create(:ink_review_submission, url: "http://example.com") }
  let(:content) { file_fixture("kobe-hatoba-blue-all-attributes.html") }

  before { stub_request(:get, ink_review_submission.url).to_return(body: content) }

  it "creates a new ink review if none exists" do
    expect do described_class.new.perform(ink_review_submission.id) end.to change(
      InkReview,
      :count
    ).by(1)
  end

  it "sets the correct attributes on the ink review" do
    described_class.new.perform(ink_review_submission.id)
    review = InkReview.first
    expect(review.url).to eq("https://mountainofink.com/blog/kobe-hatoba-blue")
    expect(review.title).to eq("Ink Review #1699: Kobe 02 Hatoba Blue — Mountain of Ink")
    expect(review.description).to eq(
      "Kobe is a brand I come back to again and again, just because I love them so much. Today let’s look at  Kobe 02 Hatoba Blue . You can find this ink for sale at most retailers including  Vanness Pens ."
    )
    expect(review.image).to eq(
      "http://static1.squarespace.com/static/591a04711e5b6c3701808c11/591a07702994cadba4aeb479/61a67ef965f99c77610c2c39/1638384095123/nk-hatoba-blue-w-1.jpg?format=1500w"
    )
    expect(review.approved_at).to eq(nil)
    expect(review.rejected_at).to eq(nil)
  end

  it "attaches the submission to the review" do
    described_class.new.perform(ink_review_submission.id)
    review = InkReview.first
    expect(review.ink_review_submissions).to eq([ink_review_submission])
  end

  it "attaches to an exsting ink review if one exists" do
    existing_review =
      create(
        :ink_review,
        url: "https://mountainofink.com/blog/kobe-hatoba-blue",
        macro_cluster: ink_review_submission.macro_cluster
      )
    expect do described_class.new.perform(ink_review_submission.id) end.not_to change(
      InkReview,
      :count
    )
    expect(existing_review.ink_review_submissions).to eq([ink_review_submission])
  end

  it "resets rejected_at of existing review" do
    existing_review =
      create(
        :ink_review,
        url: "https://mountainofink.com/blog/kobe-hatoba-blue",
        macro_cluster: ink_review_submission.macro_cluster,
        approved_at: Time.now,
        rejected_at: Time.now
      )
    expect do described_class.new.perform(ink_review_submission.id) end.not_to change(
      InkReview,
      :count
    )
    existing_review.reload
    expect(existing_review.approved_at).not_to eq(nil)
    expect(existing_review.rejected_at).to eq(nil)
  end

  it "creates a new review if url submitted only to separate cluster" do
    create(
      :ink_review,
      url: "https://mountainofink.com/blog/kobe-hatoba-blue",
      macro_cluster: create(:macro_cluster)
    )
    expect do described_class.new.perform(ink_review_submission.id) end.to change(
      InkReview,
      :count
    ).by(1)
    expect(InkReview.last.macro_cluster).to eq(ink_review_submission.macro_cluster)
  end

  context "YouTube" do
    let(:ink_review_submission) do
      create(:ink_review_submission, url: "https://www.youtube.com/watch?v=09mpgUzVc5g")
    end

    before do
      video_snippet =
        double(
          :snippet,
          {
            title: "title",
            description: "description",
            thumbnails: double(:thumbnails, maxres: double(:t, url: "url")),
            channel_title: "channel title",
            channel_id: "channel_id"
          }
        )
      video = double(:video, snippet: video_snippet)
      client = double(:client, list_videos: double(:videos, items: [video]))
      allow_any_instance_of(Unfurler::Youtube).to receive(:client).and_return(client)
      stub_request(:get, "https://www.youtube.com/shorts/09mpgUzVc5g").to_return(status: 301)
    end

    it "creates the youtube channel if it does not exist" do
      expect do described_class.new.perform(ink_review_submission.id) end.to change(
        YouTubeChannel,
        :count
      ).by(1)
      channel = YouTubeChannel.first
      expect(channel.channel_id).to eq("channel_id")
    end

    it "associates the review with the new youtube channel" do
      described_class.new.perform(ink_review_submission.id)
      channel = YouTubeChannel.first
      review = InkReview.first
      expect(review.you_tube_channel).to eq(channel)
    end

    it "associates the review with the existing youtube channel" do
      channel = create(:you_tube_channel, channel_id: "channel_id")
      expect do described_class.new.perform(ink_review_submission.id) end.not_to change(
        YouTubeChannel,
        :count
      )
      review = InkReview.first
      expect(review.you_tube_channel).to eq(channel)
    end

    it "marks it as a short if detected" do
      stub_request(:get, "https://www.youtube.com/shorts/09mpgUzVc5g").to_return(status: 200)
      described_class.new.perform(ink_review_submission.id)
      review = InkReview.first
      expect(review.you_tube_short).to eq(true)
    end
  end

  context "no image tag found" do
    let(:content) { file_fixture("kobe-hatoba-blue-no-image.html") }

    it "does not create an ink review" do
      expect do described_class.new.perform(ink_review_submission.id) end.not_to change(
        InkReview,
        :count
      )
    end

    it "saves the validation errors" do
      described_class.new.perform(ink_review_submission.id)
      expect(ink_review_submission.reload.unfurling_errors).to eq(
        { image: ["can't be blank"] }.to_json
      )
    end
  end

  context "no url found" do
    let(:content) { file_fixture("kobe-hatoba-blue-no-url.html") }

    it "takes the original url" do
      described_class.new.perform(ink_review_submission.id)
      expect(InkReview.first.url).to eq("http://example.com")
    end
  end

  it "auto approves when second submission comes in" do
    macro_cluster = create(:macro_cluster)
    submissions =
      create_list(
        :ink_review_submission,
        2,
        url: "http://example.com",
        macro_cluster: macro_cluster
      )
    expect do
      submissions.each { |submission| described_class.new.perform(submission.id) }
    end.to change(InkReview, :count).by(1)
    review = InkReview.first
    expect(review.approved_at).not_to eq(nil)
    expect(review.auto_approved).to eq(true)
  end
end
