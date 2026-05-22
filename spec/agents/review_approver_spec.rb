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

  def user_message_text(body)
    user_msg = body["messages"].find { |m| m["role"] == "user" }
    content = user_msg&.[]("content")
    return content if content.is_a?(String)
    return "" unless content.is_a?(Array)

    text_part = content.find { |p| p["type"] == "text" }
    text_part&.[]("text") || ""
  end

  describe "#initialize" do
    it "creates agent with correct owner" do
      approver = described_class.new(ink_review.id)
      expect(approver.agent_log.owner).to eq(ink_review)
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

  describe "tools" do
    let(:tool_agent_log) { AgentLog.create!(name: "test", transcript: [], owner: ink_review) }

    describe ReviewApprover::ApproveReview do
      it "has the correct description" do
        tool = described_class.new(ink_review)
        expect(tool.description).to eq("Approve the review to make it customer visible")
      end

      it "has the correct name" do
        tool = described_class.new(ink_review)
        expect(tool.name).to eq("approve_review")
      end

      it "approves the review and halts" do
        tool = described_class.new(ink_review)
        result = tool.call(explanation_of_decision: "Clearly about the ink")

        expect(result).to be_a(RubyLLM::Tool::Halt)
        ink_review.reload
        expect(ink_review.extra_data["action"]).to eq("approve_review")
        expect(ink_review.extra_data["explanation_of_decision"]).to eq("Clearly about the ink")
        expect(ink_review.approved_at).to be_present
      end

      it "merges with existing extra_data" do
        ink_review.update!(extra_data: { "existing_field" => "value" })
        tool = described_class.new(ink_review)
        tool.call(explanation_of_decision: "Test")

        ink_review.reload
        expect(ink_review.extra_data["existing_field"]).to eq("value")
        expect(ink_review.extra_data["action"]).to eq("approve_review")
      end

      it "overwrites stale action in extra_data" do
        ink_review.update!(extra_data: { "action" => "reject_review" })
        tool = described_class.new(ink_review)
        tool.call(explanation_of_decision: "Changed my mind")

        ink_review.reload
        expect(ink_review.extra_data["action"]).to eq("approve_review")
      end
    end

    describe ReviewApprover::RejectReview do
      it "has the correct description" do
        tool = described_class.new(ink_review)
        expect(tool.description).to eq("Reject the review to ensure it is hidden from public view")
      end

      it "has the correct name" do
        tool = described_class.new(ink_review)
        expect(tool.name).to eq("reject_review")
      end

      it "rejects the review and halts" do
        tool = described_class.new(ink_review)
        result = tool.call(explanation_of_decision: "Not about the ink")

        expect(result).to be_a(RubyLLM::Tool::Halt)
        ink_review.reload
        expect(ink_review.extra_data["action"]).to eq("reject_review")
        expect(ink_review.extra_data["explanation_of_decision"]).to eq("Not about the ink")
        expect(ink_review.rejected_at).to be_present
      end

      it "merges with existing extra_data" do
        ink_review.update!(extra_data: { "existing_field" => "value" })
        tool = described_class.new(ink_review)
        tool.call(explanation_of_decision: "Test")

        ink_review.reload
        expect(ink_review.extra_data["existing_field"]).to eq("value")
        expect(ink_review.extra_data["action"]).to eq("reject_review")
      end
    end

    describe ReviewApprover::Summarize do
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

      it "has the correct description" do
        tool = described_class.new(ink_review, tool_agent_log)
        expect(tool.description).to eq("Return a summary of the web page")
      end

      it "has the correct name" do
        tool = described_class.new(ink_review, tool_agent_log)
        expect(tool.name).to eq("summarize")
      end

      it "summarizes non-YouTube pages via WebPageSummarizer" do
        allow(Unfurler).to receive(:new).with(ink_review.url).and_return(
          double(perform: unfurler_result)
        )
        allow(WebPageSummarizer).to receive(:new).with(
          tool_agent_log,
          unfurler_result.raw_html
        ).and_return(double(perform: "This page is about fountain pen ink reviews."))

        tool = described_class.new(ink_review, tool_agent_log)
        result = tool.call({})

        expect(result).to eq(
          "Here is a summary of the page:\n\nThis page is about fountain pen ink reviews."
        )
      end

      it "summarizes YouTube videos via YoutubeSummarizer" do
        ink_review.update!(
          you_tube_channel: youtube_channel,
          url: "https://www.youtube.com/watch?v=abc123"
        )
        allow(ink_review).to receive(:ensure_youtube_metadata!)
        allow(WebPageSummarizer).to receive(:new)
        allow(YoutubeSummarizer).to receive(:new).with(tool_agent_log, ink_review).and_return(
          double(perform: "Reviews Pilot Tsuki-yo.")
        )

        tool = described_class.new(ink_review, tool_agent_log)
        result = tool.call({})

        expect(result).to eq("Here is a summary of the YouTube video:\n\nReviews Pilot Tsuki-yo.")
        expect(ink_review).to have_received(:ensure_youtube_metadata!)
        expect(WebPageSummarizer).not_to have_received(:new)
      end
    end
  end

  describe "#perform" do
    let(:approve_response) do
      {
        "id" => "chatcmpl-123",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_123",
                  "type" => "function",
                  "function" => {
                    "name" => "approve_review",
                    "arguments" => {
                      "explanation_of_decision" =>
                        "This review is clearly about Pilot Iroshizuku Tsuki-yo"
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 300,
          "completion_tokens" => 50,
          "total_tokens" => 350
        }
      }
    end

    let(:reject_response) do
      {
        "id" => "chatcmpl-456",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_456",
                  "type" => "function",
                  "function" => {
                    "name" => "reject_review",
                    "arguments" => {
                      "explanation_of_decision" => "This review is not related to the ink"
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 300,
          "completion_tokens" => 50,
          "total_tokens" => 350
        }
      }
    end

    context "when AI approves the review" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: approve_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "approves the review and updates agent log" do
        expect { subject.perform }.to change { AgentLog.count }.by(1)

        agent_log = AgentLog.last
        expect(agent_log.name).to eq("ReviewApprover")
        expect(agent_log.state).to eq("waiting-for-approval")
        expect(agent_log.owner).to eq(ink_review)
        expect(agent_log.extra_data["action"]).to eq("approve_review")
      end

      it "approves the ink review" do
        subject.perform
        ink_review.reload
        expect(ink_review.approved_at).to be_present
      end

      it "uses correct OpenAI model" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions").with(
          body: hash_including(model: "gpt-4.1-mini")
        ).at_least_once
      end

      it "includes tool definitions in the request" do
        subject.perform

        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).with { |req|
          body = JSON.parse(req.body)
          tools = body["tools"]
          tool_names = tools.map { |tool| tool["function"]["name"] }
          expect(tool_names).to include("approve_review")
          expect(tool_names).to include("reject_review")
          expect(tool_names).to include("summarize")
          true
        }
      end

      it "sends cluster and review data to OpenAI" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            text = user_message_text(body)

            expect(text).to include("The data for the ink is:")
            expect(text).to include("Pilot Iroshizuku Tsuki-yo")
            expect(text).to include("The review data is:")
            expect(text).to include("Great ink review")
            expect(text).to include("Here are some examples of approved reviews:")
            expect(text).to include("Here are some examples of rejected reviews:")

            true
          }
          .at_least_once
      end

      it "attaches the thumbnail as an image_url part" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            user_msg = body["messages"].find { |m| m["role"] == "user" }
            parts = user_msg["content"]

            parts.is_a?(Array) &&
              parts.any? do |p|
                p["type"] == "image_url" && p["image_url"]["url"] == ink_review.image
              end
          }
          .at_least_once
      end

      context "when the review has a blank image" do
        before { ink_review.update_column(:image, "") }

        it "sends a plain string user message" do
          subject.perform

          expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
            .with { |req|
              body = JSON.parse(req.body)
              user_msg = body["messages"].find { |m| m["role"] == "user" }
              user_msg["content"].is_a?(String)
            }
            .at_least_once
        end
      end

      context "for a YouTube review with metadata" do
        before do
          create(
            :ink_review_submission,
            ink_review: youtube_ink_review,
            user: user,
            macro_cluster: macro_cluster,
            url: youtube_ink_review.url
          )
          youtube_ink_review.update!(
            youtube_tags: %w[ink review pilot],
            youtube_comments: [
              { author: "Alice", text: "Tsuki-yo is gorgeous", like_count: 5 },
              { author: "Bob", text: "Which nib?", like_count: 2 },
              { author: "Carol", text: "Great review!", like_count: 1 },
              { author: "Dave", text: "I prefer Asa-gao", like_count: 0 }
            ],
            youtube_captions: "We are reviewing Pilot Iroshizuku Tsuki-yo today.",
            youtube_metadata_fetched_at: Time.current
          )
        end

        subject { described_class.new(youtube_ink_review.id) }

        it "includes youtube_tags, top_comments, and has_captions in the prompt JSON" do
          subject.perform

          expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
            .with { |req|
              body = JSON.parse(req.body)
              text = user_message_text(body)

              expect(text).to include("youtube_tags")
              expect(text).to include("pilot")
              expect(text).to include("top_comments")
              expect(text).to include("Tsuki-yo is gorgeous")
              expect(text).to include("has_captions")

              true
            }
            .at_least_once
        end

        it "caps top_comments at three" do
          subject.perform

          expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
            .with { |req|
              body = JSON.parse(req.body)
              text = user_message_text(body)
              # Dave's comment is fourth — must not appear.
              !text.include?("I prefer Asa-gao")
            }
            .at_least_once
        end
      end
    end

    context "when AI rejects the review" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: reject_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "rejects the review and updates agent log" do
        subject.perform

        agent_log = subject.agent_log
        expect(agent_log.state).to eq("waiting-for-approval")
        expect(agent_log.extra_data["action"]).to eq("reject_review")
      end

      it "rejects the ink review" do
        subject.perform
        ink_review.reload
        expect(ink_review.rejected_at).to be_present
      end
    end

    context "when OpenAI API returns error" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 500,
          body: { error: { message: "Internal server error" } }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises an error" do
        expect { subject.perform }.to raise_error(RubyLLM::ServerError)
      end
    end

    context "when OpenAI returns malformed JSON" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: "invalid json",
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises a parsing error" do
        expect { subject.perform }.to raise_error(Faraday::ParsingError)
      end
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

      it "marks admin users as System" do
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
        message = approver.send(:review_data)

        data = JSON.parse(message.gsub("The review data is: ", ""))
        expect(data["user"]).to eq("System")
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

        approved_data =
          JSON.parse(approved_message.gsub("Here are some examples of approved reviews: ", ""))
        rejected_data =
          JSON.parse(rejected_message.gsub("Here are some examples of rejected reviews: ", ""))

        expect(approved_data).to be_an(Array)
        expect(rejected_data).to be_an(Array)
      end

      it "matches reviews whose extra_data has keys beyond `action`" do
        approved_with_explanation =
          create(
            :ink_review,
            title: "Approved with explanation",
            url: "https://example.com/approved-explanation",
            macro_cluster: macro_cluster,
            approved_at: 1.day.ago,
            extra_data: {
              action: "approve_review",
              explanation_of_decision: "Looks like a real review"
            }
          )
        create(
          :ink_review_submission,
          ink_review: approved_with_explanation,
          user: user,
          macro_cluster: macro_cluster,
          url: approved_with_explanation.url
        )

        approver = described_class.new(ink_review.id)
        approved_message = approver.send(:approved_reviews_data)
        approved_data =
          JSON.parse(approved_message.gsub("Here are some examples of approved reviews: ", ""))

        expect(approved_data.map { |r| r["title"] }).to include("Approved with explanation")
      end
    end

    describe "#format_cluster_data" do
      it "correctly formats cluster data" do
        cluster_data = subject.send(:format_cluster_data, macro_cluster)

        expect(cluster_data[:name]).to eq(macro_cluster.name)
        expect(cluster_data[:synonyms]).to eq(macro_cluster.synonyms)
        expect(cluster_data[:number_of_reviews]).to eq(macro_cluster.ink_reviews.live.size)
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
  end

  describe "error handling" do
    context "when ink_review is not found" do
      it "raises an error" do
        expect { described_class.new(99_999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
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

        message = approver.send(:macro_cluster_data)
        cluster_data = JSON.parse(message.gsub("The data for the ink is: ", ""))

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

        message = approver.send(:review_data)
        review_data = JSON.parse(message.gsub("The review data is: ", ""))

        expect(review_data["author"]).to be_nil
      end
    end

    context "when there are no approved or rejected reviews" do
      it "returns empty arrays for examples" do
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

  describe "class constants" do
    it "has correct SYSTEM_DIRECTIVE content" do
      directive = described_class::SYSTEM_DIRECTIVE

      expect(directive).to be_a(String)
      expect(directive.length).to be > 100
      expect(directive).to include("reject")
      expect(directive).to include("approve")
    end
  end

  describe "transcript restoration" do
    let(:existing_transcript) do
      [
        { "role" => "developer", "content" => "Your task is to check if the given data..." },
        { "role" => "user", "content" => "The year is 2026." },
        {
          "role" => "assistant",
          "content" => "",
          "tool_calls" => [{ "id" => "call_prev", "name" => "summarize", "arguments" => {} }]
        },
        {
          "role" => "tool",
          "content" => "Here is a summary of the page:\n\nThis is about ink.",
          "tool_call_id" => "call_prev"
        }
      ]
    end

    let(:continued_response) do
      {
        "id" => "chatcmpl-continued",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_new",
                  "type" => "function",
                  "function" => {
                    "name" => "approve_review",
                    "arguments" => {
                      "explanation_of_decision" => "The summary confirms this is about the ink"
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 50,
          "total_tokens" => 150
        }
      }
    end

    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: continued_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "restores messages including tool calls from an existing transcript" do
      agent_log =
        ink_review.agent_logs.create!(
          name: "ReviewApprover",
          state: "processing",
          transcript: existing_transcript
        )

      approver = described_class.new(ink_review.id)
      approver.instance_variable_set(:@agent_log, agent_log)

      approver.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        messages = body["messages"]

        user_restored = messages.find { |m| m["role"] == "user" && m["content"]&.include?("2026") }
        assistant_restored = messages.find { |m| m["role"] == "assistant" && m["tool_calls"]&.any? }
        tool_restored =
          messages.find { |m| m["role"] == "tool" && m["tool_call_id"] == "call_prev" }

        user_restored && assistant_restored && tool_restored &&
          assistant_restored["tool_calls"].first["id"] == "call_prev"
      }
    end
  end

  describe "transcript and usage tracking" do
    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: approve_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    let(:approve_response) do
      {
        "id" => "chatcmpl-123",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_123",
                  "type" => "function",
                  "function" => {
                    "name" => "approve_review",
                    "arguments" => {
                      "explanation_of_decision" => "Review is about the ink"
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 300,
          "completion_tokens" => 50,
          "total_tokens" => 350
        }
      }
    end

    it "updates agent log transcript" do
      subject.perform

      transcript = subject.agent_log.transcript
      expect(transcript).to be_an(Array)
      expect(transcript.length).to be >= 3
      expect(transcript.any? { |e| e["role"] == "user" }).to be true
      expect(transcript.any? { |e| e["role"] == "assistant" }).to be true
    end

    it "updates agent log usage" do
      subject.perform

      usage = subject.agent_log.usage
      expect(usage["prompt_tokens"]).to eq(300)
      expect(usage["completion_tokens"]).to eq(50)
      expect(usage["total_tokens"]).to eq(350)
      expect(usage["model"]).to eq("gpt-4.1-mini")
    end
  end
end
