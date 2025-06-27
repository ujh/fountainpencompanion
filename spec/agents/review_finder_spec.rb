require "rails_helper"

RSpec.describe ReviewFinder do
  before(:each) do
    WebMock.reset!
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end

  let(:page) { create(:web_page_for_review, url: "https://example.com/review", state: "pending") }

  let(:macro_cluster) do
    create(:macro_cluster, brand_name: "Pilot", line_name: "Iroshizuku", ink_name: "Tsuki-yo")
  end

  let(:unfurler_result) do
    Unfurler::Result.new(
      "https://example.com/review",
      "Great Ink Review",
      "A detailed review of Pilot Iroshizuku Tsuki-yo fountain pen ink",
      "https://example.com/image.jpg",
      "Review Author",
      nil,
      false,
      "<html><body>Raw HTML content</body></html>"
    )
  end

  let(:youtube_unfurler_result) do
    Unfurler::Result.new(
      "https://www.youtube.com/watch?v=abc123",
      "YouTube Ink Review",
      "Video review of fountain pen inks",
      "https://img.youtube.com/vi/abc123/maxresdefault.jpg",
      "YouTube Author",
      "UC123456789",
      false,
      nil
    )
  end

  before { allow_any_instance_of(Unfurler).to receive(:perform).and_return(unfurler_result) }

  subject { described_class.new(page) }

  describe "#initialize" do
    it "creates agent with correct page" do
      finder = described_class.new(page)
      expect(finder.agent_log.owner).to eq(page)
    end

    it "creates agent log with correct name" do
      finder = described_class.new(page)
      expect(finder.agent_log.name).to eq("ReviewFinder")
    end

    it "initializes transcript with system directive" do
      finder = described_class.new(page)
      transcript_messages = finder.transcript.to_a

      system_message = transcript_messages.find { |msg| msg.key?(:system) }
      expect(system_message).to be_present
      expect(system_message[:system]).to include("fountain pen inks")
      expect(system_message[:system]).to include("similarity")
      expect(system_message[:system]).to include("search")
    end

    it "includes user message in transcript" do
      finder = described_class.new(page)
      transcript_messages = finder.transcript.to_a

      user_message = transcript_messages.find { |msg| msg.key?(:user) }
      expect(user_message).to be_present
      expect(user_message[:user]).to include("page data")
    end

    it "uses existing transcript when present" do
      existing_transcript = [
        { system: "Existing system message" },
        { user: "Existing user message" }
      ]
      page.agent_logs.create!(
        name: "ReviewFinder",
        transcript: existing_transcript,
        state: "processing"
      )

      finder = described_class.new(page)
      expect(finder.transcript.to_a).to eq(existing_transcript)
    end
  end

  describe "#agent_log" do
    it "creates and persists agent log" do
      log = subject.agent_log

      expect(log).to be_persisted
      expect(log.name).to eq("ReviewFinder")
      expect(log.owner).to eq(page)
      expect(log.state).to eq("processing")
    end

    it "memoizes agent log" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to eq(log2)
    end

    it "finds existing processing agent log" do
      existing_log =
        page.agent_logs.create!(name: "ReviewFinder", state: "processing", transcript: [])

      expect(subject.agent_log).to eq(existing_log)
    end
  end

  describe "#perform" do
    it "calls chat_completion with correct model" do
      expect(subject).to receive(:chat_completion).with(openai: "gpt-4.1")
      expect(subject.agent_log).to receive(:waiting_for_approval!)

      subject.perform
    end

    it "updates agent log state to waiting for approval" do
      allow(subject).to receive(:chat_completion)

      subject.perform

      expect(subject.agent_log.state).to eq("waiting-for-approval")
    end
  end

  describe "error handling" do
    context "when Unfurler raises an error" do
      it "allows the error to propagate during initialization" do
        allow_any_instance_of(Unfurler).to receive(:perform).and_raise(
          StandardError,
          "Network error"
        )

        expect { described_class.new(page) }.to raise_error(StandardError, "Network error")
      end
    end
  end

  describe "integration scenarios" do
    context "with YouTube videos" do
      let(:youtube_page) do
        create(:web_page_for_review, url: "https://www.youtube.com/watch?v=abc123")
      end

      before do
        allow_any_instance_of(Unfurler).to receive(:perform).and_return(youtube_unfurler_result)
      end

      it "can process YouTube video pages" do
        finder = described_class.new(youtube_page)

        expect(finder.agent_log).to be_persisted
        expect(finder.agent_log.owner).to eq(youtube_page)
        expect(finder.transcript.to_a).not_to be_empty
      end

      it "includes YouTube URL in transcript" do
        finder = described_class.new(youtube_page)
        transcript_messages = finder.transcript.to_a

        user_message = transcript_messages.find { |msg| msg.key?(:user) }
        expect(user_message[:user]).to include("youtube.com")
      end
    end

    context "complete workflow" do
      it "can be initialized and performed" do
        finder = described_class.new(page)
        allow(finder).to receive(:chat_completion)

        expect(finder.agent_log.state).to eq("processing")

        finder.perform

        expect(finder.agent_log.state).to eq("waiting-for-approval")
      end

      it "has all necessary components for review processing" do
        finder = described_class.new(page)

        # Verify page is accessible
        expect(finder.agent_log.owner).to eq(page)

        # Verify transcript is initialized
        expect(finder.transcript.to_a).not_to be_empty

        # Verify cluster exists for potential submission
        expect(macro_cluster).to be_persisted
        expect(macro_cluster.name).to be_present
      end
    end
  end

  describe "transcript management" do
    it "includes system directive in transcript" do
      system_message = subject.transcript.to_a.find { |msg| msg.key?(:system) }

      expect(system_message[:system]).to eq(described_class::SYSTEM_DIRECTIVE)
    end

    it "includes page data in user message" do
      user_message = subject.transcript.to_a.find { |msg| msg.key?(:user) }

      expect(user_message[:user]).to include("page data")
      expect(user_message[:user]).to include(page.url)
    end

    it "preserves existing transcript when agent_log has one" do
      existing_transcript = [{ system: "Custom system message" }, { user: "Custom user message" }]

      page.agent_logs.create!(
        name: "ReviewFinder",
        transcript: existing_transcript,
        state: "processing"
      )

      finder = described_class.new(page)
      expect(finder.transcript.to_a).to eq(existing_transcript)
    end
  end

  describe "state transitions" do
    it "starts in processing state" do
      expect(subject.agent_log.state).to eq("processing")
    end

    it "transitions to waiting-for-approval after perform" do
      allow(subject).to receive(:chat_completion)

      subject.perform

      expect(subject.agent_log.reload.state).to eq("waiting-for-approval")
    end
  end

  describe "OpenAI integration and tool calls" do
    let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

    context "when AI decides to submit a review" do
      let(:submit_review_response) do
        {
          "id" => "chatcmpl-review-123",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_submit_review",
                    "type" => "function",
                    "function" => {
                      "name" => "submit_review",
                      "arguments" => {
                        "ink_cluster_id" => macro_cluster.id,
                        "explanation" =>
                          "This page contains a detailed review of Pilot Iroshizuku Tsuki-yo ink."
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 150,
            "completion_tokens" => 25,
            "total_tokens" => 175
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: submit_review_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "enqueues review submission job when AI calls submit_review" do
        subject.perform

        # Find jobs that contain our specific cluster ID and page URL
        matching_jobs =
          FetchReviews::SubmitReview.jobs.select do |job|
            job["args"][0] == page.url && job["args"][1] == macro_cluster.id
          end

        # Verify at least one job was enqueued for our review
        expect(matching_jobs.size).to be >= 1

        # Verify the job has correct arguments
        job = matching_jobs.first
        expect(job["args"]).to eq(
          [
            page.url,
            macro_cluster.id,
            "This page contains a detailed review of Pilot Iroshizuku Tsuki-yo ink."
          ]
        )
      end

      it "makes correct HTTP request to OpenAI" do
        subject.perform

        expect(WebMock).to have_requested(:post, openai_url).at_least_once
      end

      it "updates agent log state after tool call" do
        subject.perform

        expect(subject.agent_log.reload.state).to eq("waiting-for-approval")
      end
    end

    context "when AI decides to complete without submitting reviews" do
      let(:done_response) do
        {
          "id" => "chatcmpl-done-123",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_done",
                    "type" => "function",
                    "function" => {
                      "name" => "done",
                      "arguments" => {
                        "summary" =>
                          "This page does not contain ink reviews suitable for submission."
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 120,
            "completion_tokens" => 20,
            "total_tokens" => 140
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: done_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "does not enqueue any review submission jobs" do
        subject.perform

        # Verify no jobs were enqueued for our specific page when calling done
        page_jobs = FetchReviews::SubmitReview.jobs.select { |job| job["args"][0] == page.url }

        expect(page_jobs.size).to eq(0)
      end

      it "updates agent log with summary" do
        subject.perform

        expect(subject.agent_log.reload.extra_data["summary"]).to eq(
          "This page does not contain ink reviews suitable for submission."
        )
      end
    end

    context "when AI submits multiple reviews" do
      let(:cluster2) do
        create(:macro_cluster, brand_name: "Sailor", line_name: "Jentle", ink_name: "Yama-dori")
      end

      let(:multiple_reviews_response) do
        {
          "id" => "chatcmpl-multiple-123",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_submit_review_1",
                    "type" => "function",
                    "function" => {
                      "name" => "submit_review",
                      "arguments" => {
                        "ink_cluster_id" => macro_cluster.id,
                        "explanation" =>
                          "Review mentions Pilot Iroshizuku Tsuki-yo with detailed color analysis."
                      }.to_json
                    }
                  },
                  {
                    "id" => "call_submit_review_2",
                    "type" => "function",
                    "function" => {
                      "name" => "submit_review",
                      "arguments" => {
                        "ink_cluster_id" => cluster2.id,
                        "explanation" =>
                          "Page also contains comparison with Sailor Jentle Yama-dori."
                      }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 200,
            "completion_tokens" => 45,
            "total_tokens" => 245
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: multiple_reviews_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "enqueues multiple review submission jobs" do
        subject.perform

        # Find jobs for our specific clusters and page
        cluster1_jobs =
          FetchReviews::SubmitReview.jobs.select do |job|
            job["args"][0] == page.url && job["args"][1] == macro_cluster.id
          end

        cluster2_jobs =
          FetchReviews::SubmitReview.jobs.select do |job|
            job["args"][0] == page.url && job["args"][1] == cluster2.id
          end

        # Verify jobs were enqueued for both clusters
        expect(cluster1_jobs.size).to be >= 1
        expect(cluster2_jobs.size).to be >= 1

        # Verify job arguments contain expected explanations
        expect(cluster1_jobs.first["args"][2]).to include("Pilot Iroshizuku Tsuki-yo")
        expect(cluster2_jobs.first["args"][2]).to include("Sailor Jentle Yama-dori")
      end
    end

    context "when OpenAI API returns an error" do
      before do
        stub_request(:post, openai_url).to_return(status: 500, body: "Internal Server Error")
      end

      it "raises an error and does not enqueue jobs" do
        initial_job_count = FetchReviews::SubmitReview.jobs.size

        expect { subject.perform }.to raise_error(Faraday::ServerError)

        # Job count should remain the same
        expect(FetchReviews::SubmitReview.jobs.size).to eq(initial_job_count)
      end
    end
  end
end
