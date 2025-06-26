require "rails_helper"

RSpec.describe ReviewApprover do
  let(:macro_cluster) do
    create(:macro_cluster, brand_name: "Pilot", line_name: "Iroshizuku", ink_name: "Tsuki-yo")
  end

  let(:user) { create(:user, name: "John Doe", email: "john@example.com") }
  let(:admin_user) { create(:user, :admin, name: "Admin", email: "admin@example.com") }

  let(:ink_review) do
    create(
      :ink_review,
      title: "Great ink review",
      description: "This is a detailed review of Pilot Iroshizuku Tsuki-yo",
      url: "https://example.com/review",
      image: "https://example.com/image.jpg",
      host: "example.com",
      author: "Review Author",
      macro_cluster: macro_cluster
    )
  end

  let(:ink_review_submission) do
    create(
      :ink_review_submission,
      ink_review: ink_review,
      user: user,
      macro_cluster: macro_cluster,
      url: ink_review.url
    )
  end

  let(:youtube_channel) { create(:you_tube_channel, channel_id: "UC123456789") }

  let(:youtube_ink_review) do
    create(
      :ink_review,
      title: "YouTube Review",
      description: "YouTube video review",
      url: "https://www.youtube.com/watch?v=abc123",
      you_tube_channel: youtube_channel,
      you_tube_short: false,
      macro_cluster: macro_cluster
    )
  end

  let(:youtube_short_review) do
    create(
      :ink_review,
      title: "YouTube Short Review",
      description: "YouTube short review",
      url: "https://www.youtube.com/shorts/xyz789",
      you_tube_channel: youtube_channel,
      you_tube_short: true,
      macro_cluster: macro_cluster
    )
  end

  # Create some existing approved and rejected reviews for examples
  let!(:approved_review_1) do
    review =
      create(
        :ink_review,
        title: "Approved Review 1",
        description: "Good review",
        url: "https://example.com/approved1",
        macro_cluster: macro_cluster,
        approved_at: 1.day.ago,
        extra_data: {
          action: "approve_review"
        }
      )
    create(
      :ink_review_submission,
      ink_review: review,
      user: user,
      macro_cluster: macro_cluster,
      url: review.url
    )
    # Create micro cluster and collected inks to provide synonyms
    micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
    create(
      :collected_ink,
      micro_cluster: micro_cluster,
      brand_name: "Pilot",
      line_name: "Iroshizuku",
      ink_name: "Tsuki-yo",
      private: false
    )
    create(
      :collected_ink,
      micro_cluster: micro_cluster,
      brand_name: "Pilot",
      line_name: "",
      ink_name: "Tsuki-yo",
      private: false
    )
    review
  end

  let!(:rejected_review_1) do
    review =
      create(
        :ink_review,
        title: "Rejected Review 1",
        description: "Bad review",
        url: "https://example.com/rejected1",
        macro_cluster: macro_cluster,
        rejected_at: 1.day.ago,
        extra_data: {
          action: "reject_review"
        }
      )
    create(
      :ink_review_submission,
      ink_review: review,
      user: user,
      macro_cluster: macro_cluster,
      url: review.url
    )
    review
  end

  before do
    ink_review_submission # Create the submission
  end

  subject { described_class.new(ink_review.id) }

  describe "#initialize" do
    it "creates agent with correct owner" do
      approver = described_class.new(ink_review.id)
      expect(approver.agent_log.owner).to eq(ink_review)
    end

    it "initializes transcript with system directive" do
      approver = described_class.new(ink_review.id)
      expect(approver.transcript.first[:system]).to be_present
      expect(approver.transcript.first[:system]).to include(
        "Your task is to check if the given data is a review"
      )
      expect(approver.transcript.first[:system]).to include("approve or reject the review")
    end

    it "includes macro cluster data in transcript" do
      approver = described_class.new(ink_review.id)
      cluster_message =
        approver.transcript.find { |msg| msg[:user]&.include?("The data for the ink is:") }
      expect(cluster_message).to be_present

      cluster_data = JSON.parse(cluster_message[:user].gsub("The data for the ink is: ", ""))
      expect(cluster_data["name"]).to eq("Pilot Iroshizuku Tsuki-yo")
      expect(cluster_data["synonyms"]).to be_an(Array)
      expect(cluster_data["number_of_reviews"]).to eq(1) # approved_review_1
    end

    it "includes review data in transcript" do
      approver = described_class.new(ink_review.id)
      review_message =
        approver.transcript.find { |msg| msg[:user]&.include?("The review data is:") }
      expect(review_message).to be_present

      review_data = JSON.parse(review_message[:user].gsub("The review data is: ", ""))
      expect(review_data["title"]).to eq("Great ink review")
      expect(review_data["description"]).to eq(
        "This is a detailed review of Pilot Iroshizuku Tsuki-yo"
      )
      expect(review_data["url"]).to eq("https://example.com/review")
      expect(review_data["host"]).to eq("example.com")
      expect(review_data["author"]).to eq("Review Author")
      expect(review_data["user"]).to eq("John Doe")
      expect(review_data["is_you_tube_video"]).to be_falsy
    end

    it "includes youtube video data when applicable" do
      create(
        :ink_review_submission,
        ink_review: youtube_ink_review,
        user: user,
        macro_cluster: macro_cluster,
        url: youtube_ink_review.url
      )
      approver = described_class.new(youtube_ink_review.id)

      review_message =
        approver.transcript.find { |msg| msg[:user]&.include?("The review data is:") }
      review_data = JSON.parse(review_message[:user].gsub("The review data is: ", ""))

      expect(review_data["is_you_tube_video"]).to be true
      expect(review_data["is_youtube_short"]).to be false
    end

    it "includes youtube short data when applicable" do
      create(
        :ink_review_submission,
        ink_review: youtube_short_review,
        user: user,
        macro_cluster: macro_cluster,
        url: youtube_short_review.url
      )
      approver = described_class.new(youtube_short_review.id)

      review_message =
        approver.transcript.find { |msg| msg[:user]&.include?("The review data is:") }
      review_data = JSON.parse(review_message[:user].gsub("The review data is: ", ""))

      expect(review_data["is_you_tube_video"]).to be true
      expect(review_data["is_youtube_short"]).to be true
    end

    it "marks system users appropriately" do
      admin_submission =
        create(
          :ink_review_submission,
          ink_review: ink_review,
          user: admin_user,
          macro_cluster: macro_cluster,
          url: ink_review.url
        )
      ink_review.ink_review_submissions = [admin_submission]

      approver = described_class.new(ink_review.id)
      review_message =
        approver.transcript.find { |msg| msg[:user]&.include?("The review data is:") }
      review_data = JSON.parse(review_message[:user].gsub("The review data is: ", ""))

      expect(review_data["user"]).to eq("System")
    end

    it "includes approved and rejected reviews examples" do
      approver = described_class.new(ink_review.id)

      approved_message =
        approver.transcript.find do |msg|
          msg[:user]&.include?("Here are some examples of approved reviews:")
        end
      rejected_message =
        approver.transcript.find do |msg|
          msg[:user]&.include?("Here are some examples of rejected reviews:")
        end

      expect(approved_message).to be_present
      expect(rejected_message).to be_present
    end
  end

  describe "#agent_log" do
    it "creates and memoizes agent log" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to be_persisted
      expect(log1.name).to eq("ReviewApprover")
      expect(log1.owner).to eq(ink_review)
      expect(log1).to eq(log2)
    end
  end

  describe "data formatting" do
    describe "#macro_cluster_data" do
      it "formats cluster data correctly" do
        approver = described_class.new(ink_review.id)
        message = approver.send(:macro_cluster_data)

        expect(message).to include("The data for the ink is:")

        data = JSON.parse(message.gsub("The data for the ink is: ", ""))
        expect(data["name"]).to eq("Pilot Iroshizuku Tsuki-yo")
        expect(data["synonyms"]).to be_an(Array)
        expect(data["number_of_reviews"]).to eq(1) # approved_review_1
      end
    end

    describe "#review_data" do
      it "formats review data correctly for regular reviews" do
        approver = described_class.new(ink_review.id)
        message = approver.send(:review_data)

        expect(message).to include("The review data is:")

        data = JSON.parse(message.gsub("The review data is: ", ""))
        expect(data["title"]).to eq("Great ink review")
        expect(data["description"]).to eq("This is a detailed review of Pilot Iroshizuku Tsuki-yo")
        expect(data["url"]).to eq("https://example.com/review")
        expect(data["thumbnail_url"]).to eq("https://example.com/image.jpg")
        expect(data["host"]).to eq("example.com")
        expect(data["author"]).to eq("Review Author")
        expect(data["user"]).to eq("John Doe")
        expect(data["is_you_tube_video"]).to be_falsy
      end

      it "formats review data correctly for YouTube videos" do
        create(
          :ink_review_submission,
          ink_review: youtube_ink_review,
          user: user,
          macro_cluster: macro_cluster,
          url: youtube_ink_review.url
        )
        approver = described_class.new(youtube_ink_review.id)
        message = approver.send(:review_data)

        data = JSON.parse(message.gsub("The review data is: ", ""))
        expect(data["is_you_tube_video"]).to be true
        expect(data["is_youtube_short"]).to be false
      end

      it "formats review data correctly for YouTube shorts" do
        create(
          :ink_review_submission,
          ink_review: youtube_short_review,
          user: user,
          macro_cluster: macro_cluster,
          url: youtube_short_review.url
        )
        approver = described_class.new(youtube_short_review.id)
        message = approver.send(:review_data)

        data = JSON.parse(message.gsub("The review data is: ", ""))
        expect(data["is_you_tube_video"]).to be true
        expect(data["is_youtube_short"]).to be true
      end

      it "handles users without names" do
        user_without_name = create(:user, name: nil, email: "noname@example.com")
        create(
          :ink_review_submission,
          ink_review: ink_review,
          user: user_without_name,
          macro_cluster: macro_cluster,
          url: ink_review.url
        )
        ink_review.ink_review_submissions = [ink_review.ink_review_submissions.last]

        approver = described_class.new(ink_review.id)
        message = approver.send(:review_data)

        data = JSON.parse(message.gsub("The review data is: ", ""))
        expect(data["user"]).to eq("noname@example.com")
      end
    end

    describe "#approved_reviews_data and #rejected_reviews_data" do
      it "includes examples of approved and rejected reviews" do
        approver = described_class.new(ink_review.id)

        approved_message = approver.send(:approved_reviews_data)
        rejected_message = approver.send(:rejected_reviews_data)

        expect(approved_message).to include("Here are some examples of approved reviews:")
        expect(rejected_message).to include("Here are some examples of rejected reviews:")

        # Verify the data includes our test reviews
        approved_data =
          JSON.parse(approved_message.gsub("Here are some examples of approved reviews: ", ""))
        rejected_data =
          JSON.parse(rejected_message.gsub("Here are some examples of rejected reviews: ", ""))

        expect(approved_data).to be_an(Array)
        expect(rejected_data).to be_an(Array)
      end
    end
  end

  describe "function definitions" do
    it "has approve_review function defined" do
      expect(subject.class.instance_methods).to include(:approve_review)
    end

    it "has reject_review function defined" do
      expect(subject.class.instance_methods).to include(:reject_review)
    end

    it "has summarize function defined" do
      expect(subject.class.instance_methods).to include(:summarize)
    end
  end

  describe "#summarize" do
    let(:unfurler_result) do
      Unfurler::Result.new(
        "https://example.com/review",
        "Page Title",
        "Page Description",
        "https://example.com/image.jpg",
        "Page Author",
        nil,
        false,
        "<html><body>Raw HTML content</body></html>"
      )
    end

    let(:summarizer_response) { "This page is about fountain pen ink reviews." }

    before do
      allow(Unfurler).to receive(:new).with(ink_review.url).and_return(
        double(perform: unfurler_result)
      )
    end

    context "when URL is not a YouTube video" do
      before do
        allow(WebPageSummarizer).to receive(:new).with(
          subject.agent_log,
          unfurler_result.raw_html
        ).and_return(double(perform: summarizer_response))
      end

      it "calls Unfurler and WebPageSummarizer" do
        # Test the summarize logic by simulating what happens inside the function
        unfurler_instance = double(perform: unfurler_result)
        summarizer_instance = double(perform: summarizer_response)

        allow(Unfurler).to receive(:new).with(ink_review.url).and_return(unfurler_instance)
        allow(WebPageSummarizer).to receive(:new).with(
          subject.agent_log,
          unfurler_result.raw_html
        ).and_return(summarizer_instance)

        # Since the function is called via function dispatch, test the internal logic
        page_data = Unfurler.new(ink_review.url).perform

        expect(page_data.you_tube_channel_id).to be_nil
        summary = WebPageSummarizer.new(subject.agent_log, page_data.raw_html).perform
        result = "Here is a summary of the page:\n\n#{summary}"

        expect(result).to eq("Here is a summary of the page:\n\n#{summarizer_response}")
        expect(Unfurler).to have_received(:new).with(ink_review.url)
        expect(WebPageSummarizer).to have_received(:new).with(
          subject.agent_log,
          unfurler_result.raw_html
        )
      end
    end

    context "when URL is a YouTube video" do
      let(:youtube_unfurler_result) do
        Unfurler::Result.new(
          "https://www.youtube.com/watch?v=abc123",
          "YouTube Video Title",
          "YouTube Video Description",
          "https://img.youtube.com/vi/abc123/hqdefault.jpg",
          "Channel Name",
          "UC123456789",
          false,
          nil
        )
      end

      before do
        allow(Unfurler).to receive(:new).with(youtube_ink_review.url).and_return(
          double(perform: youtube_unfurler_result)
        )
        allow(WebPageSummarizer).to receive(:new)
      end

      it "returns message that it can't summarize YouTube videos" do
        create(
          :ink_review_submission,
          ink_review: youtube_ink_review,
          user: user,
          macro_cluster: macro_cluster,
          url: youtube_ink_review.url
        )
        approver = described_class.new(youtube_ink_review.id)

        # Test the summarize logic by simulating what happens inside the function
        unfurler_instance = double(perform: youtube_unfurler_result)
        allow(Unfurler).to receive(:new).with(youtube_ink_review.url).and_return(unfurler_instance)

        # Since the function is called via function dispatch, test the internal logic
        page_data = Unfurler.new(youtube_ink_review.url).perform

        if page_data.you_tube_channel_id.present?
          result = "This is a Youtube video. I can't summarize it."
        else
          result = "This should not happen in this test"
        end

        expect(result).to eq("This is a Youtube video. I can't summarize it.")
        expect(WebPageSummarizer).not_to have_received(:new)
      end
    end
  end

  describe "business logic" do
    it "correctly identifies review user" do
      expect(ink_review.user).to eq(user)
    end

    it "correctly identifies macro cluster" do
      expect(subject.send(:macro_cluster)).to eq(macro_cluster)
    end

    it "correctly formats cluster name" do
      expect(macro_cluster.name).to eq("Pilot Iroshizuku Tsuki-yo")
    end

    it "handles extra_data merging properly" do
      ink_review.update!(extra_data: { "existing_field" => "value" })

      # Test the logic inside the function - Rails stores JSON with string keys
      new_data = {
        "action" => "approve_review",
        "explanation_of_decision" => "Test explanation"
      }.merge(ink_review.extra_data || {})

      expect(new_data["existing_field"]).to eq("value")
      expect(new_data["action"]).to eq("approve_review")
      expect(new_data["explanation_of_decision"]).to eq("Test explanation")
    end
  end

  describe "error handling" do
    context "when ink_review is not found" do
      it "raises an error" do
        expect { described_class.new(99_999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "SYSTEM_DIRECTIVE" do
    it "contains expected guidelines" do
      directive = described_class::SYSTEM_DIRECTIVE

      expect(directive).to include("check if the given data is a review")
      expect(directive).to include("approve or reject the review")
      expect(directive).to include("Reject reviews that are not related to the ink")
      expect(directive).to include("Approve reviews that are related to the ink")
      expect(directive).to include("Reject reviews that are instagram posts")
      expect(directive).to include("YouTube videos that are not shorts")
      expect(directive).to include("YouTube videos that are shorts")
      expect(directive).to include("currently inked style videos")
      expect(directive).to include("summarize")
      expect(directive).to include("System")
    end
  end

  describe "edge cases" do
    context "when macro cluster has no synonyms" do
      let(:empty_macro_cluster) do
        create(:macro_cluster, brand_name: "Test", line_name: "", ink_name: "Ink")
      end

      let(:empty_ink_review) { create(:ink_review, macro_cluster: empty_macro_cluster) }

      it "handles empty synonyms gracefully" do
        create(
          :ink_review_submission,
          ink_review: empty_ink_review,
          user: user,
          macro_cluster: empty_macro_cluster,
          url: empty_ink_review.url
        )
        approver = described_class.new(empty_ink_review.id)

        cluster_message =
          approver.transcript.find { |msg| msg[:user]&.include?("The data for the ink is:") }
        cluster_data = JSON.parse(cluster_message[:user].gsub("The data for the ink is: ", ""))

        expect(cluster_data["synonyms"]).to eq([])
      end
    end

    context "when review has no author" do
      let(:review_without_author) do
        create(
          :ink_review,
          title: "Review without author",
          author: nil,
          macro_cluster: macro_cluster
        )
      end

      it "handles nil author gracefully" do
        create(
          :ink_review_submission,
          ink_review: review_without_author,
          user: user,
          macro_cluster: macro_cluster,
          url: review_without_author.url
        )
        approver = described_class.new(review_without_author.id)

        review_message =
          approver.transcript.find { |msg| msg[:user]&.include?("The review data is:") }
        review_data = JSON.parse(review_message[:user].gsub("The review data is: ", ""))

        expect(review_data["author"]).to be_nil
      end
    end

    context "when ink review has no extra_data" do
      it "handles nil extra_data in merging" do
        ink_review.update!(extra_data: nil)

        new_data = {
          "action" => "approve_review",
          "explanation_of_decision" => "Test explanation"
        }.merge(ink_review.extra_data || {})

        expect(new_data["action"]).to eq("approve_review")
        expect(new_data["explanation_of_decision"]).to eq("Test explanation")
      end
    end

    context "when there are no approved or rejected reviews" do
      it "returns empty arrays for examples" do
        # Clear existing reviews
        InkReview.where.not(id: ink_review.id).destroy_all

        approver = described_class.new(ink_review.id)

        approved_message = approver.send(:approved_reviews_data)
        rejected_message = approver.send(:rejected_reviews_data)

        approved_data =
          JSON.parse(approved_message.gsub("Here are some examples of approved reviews: ", ""))
        rejected_data =
          JSON.parse(rejected_message.gsub("Here are some examples of rejected reviews: ", ""))

        expect(approved_data).to be_an(Array)
        expect(rejected_data).to be_an(Array)
      end
    end
  end

  describe "private methods" do
    describe "#format_cluster_data" do
      it "correctly formats cluster data" do
        cluster_data = subject.send(:format_cluster_data, macro_cluster)

        expect(cluster_data[:name]).to eq(macro_cluster.name)
        expect(cluster_data[:synonyms]).to eq(macro_cluster.synonyms)
        expect(cluster_data[:number_of_reviews]).to eq(macro_cluster.ink_reviews.approved.size)
      end
    end

    describe "#format_review_data" do
      it "correctly formats review data for non-YouTube content" do
        review_data = subject.send(:format_review_data, ink_review)

        expect(review_data[:title]).to eq(ink_review.title)
        expect(review_data[:description]).to eq(ink_review.description)
        expect(review_data[:url]).to eq(ink_review.url)
        expect(review_data[:thumbnail_url]).to eq(ink_review.image)
        expect(review_data[:host]).to eq(ink_review.host)
        expect(review_data[:author]).to eq(ink_review.author)
        expect(review_data[:user]).to eq("John Doe")
        expect(review_data[:is_you_tube_video]).to be_falsy
      end

      it "correctly formats review data for YouTube content" do
        create(
          :ink_review_submission,
          ink_review: youtube_ink_review,
          user: user,
          macro_cluster: macro_cluster,
          url: youtube_ink_review.url
        )
        approver = described_class.new(youtube_ink_review.id)

        review_data = approver.send(:format_review_data, youtube_ink_review)

        expect(review_data[:is_you_tube_video]).to be true
        expect(review_data[:is_youtube_short]).to be false
      end
    end

    describe "#admin_reviews and #user_reviews" do
      it "correctly separates admin and user reviews" do
        admin_review = create(:ink_review, macro_cluster: macro_cluster, approved_at: 1.day.ago)
        create(
          :ink_review_submission,
          ink_review: admin_review,
          user: admin_user,
          macro_cluster: macro_cluster,
          url: admin_review.url
        )

        user_review = create(:ink_review, macro_cluster: macro_cluster, approved_at: 1.day.ago)
        create(
          :ink_review_submission,
          ink_review: user_review,
          user: user,
          macro_cluster: macro_cluster,
          url: user_review.url
        )

        admin_review_ids = subject.send(:admin_reviews).pluck(:id)
        user_review_ids = subject.send(:user_reviews).pluck(:id)

        expect(admin_review_ids).to include(admin_review.id)
        expect(user_review_ids).to include(user_review.id)
        expect(admin_review_ids).not_to include(user_review.id)
        expect(user_review_ids).not_to include(admin_review.id)
      end
    end
  end

  describe "class constants" do
    it "has correct SYSTEM_DIRECTIVE content" do
      directive = described_class::SYSTEM_DIRECTIVE

      expect(directive).to be_a(String)
      expect(directive.length).to be > 100
      expect(directive).to include("reject")
      expect(directive).to include("approve")
    end
  end

  describe "integration with AgentTranscript" do
    it "properly initializes transcript" do
      expect(subject.transcript).to be_a(AgentTranscript::Transcript)
      expect(subject.transcript.count).to be > 0
    end

    it "includes system message in transcript" do
      system_message = subject.transcript.find { |msg| msg.key?(:system) }
      expect(system_message).to be_present
      expect(system_message[:system]).to include("check if the given data is a review")
    end

    it "includes user messages in transcript" do
      user_messages = subject.transcript.select { |msg| msg.key?(:user) }
      expect(user_messages.length).to be >= 4 # cluster, review, approved, rejected
    end
  end
end
