require "rails_helper"

RSpec.describe ReviewFinder do
  before do
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
  before do
    allow(ResolveImageUrl).to receive(:new) do |passed_url|
      double("ResolveImageUrl", perform: passed_url.presence)
    end
  end

  subject { described_class.new(page) }

  def user_message_text(body)
    user_msg = body["messages"].find { |m| m["role"] == "user" }
    content = user_msg&.[]("content")
    return content if content.is_a?(String)
    return "" unless content.is_a?(Array)

    text_part = content.find { |p| p["type"] == "text" }
    text_part&.[]("text") || ""
  end

  describe "#initialize" do
    it "creates agent with correct page" do
      finder = described_class.new(page)
      expect(finder.agent_log.owner).to eq(page)
    end

    it "creates agent log with correct name" do
      finder = described_class.new(page)
      expect(finder.agent_log.name).to eq("ReviewFinder")
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

  describe "tools" do
    let(:tool_agent_log) { AgentLog.create!(name: "test", transcript: [], owner: page) }

    describe ReviewFinder::SubmitReview do
      it "has the correct name" do
        tool = described_class.new(page)
        expect(tool.name).to eq("submit_review")
      end

      it "has the correct description" do
        tool = described_class.new(page)
        expect(tool.description).to eq("Submit a review for the ink clusters")
      end

      it "enqueues review submission job when cluster exists" do
        tool = described_class.new(page)
        result = tool.call(ink_cluster_id: macro_cluster.id, explanation: "This is about the ink")

        expect(result).to include("submitted the review")
        expect(result).to include(macro_cluster.name)

        matching_jobs =
          FetchReviews::SubmitReview.jobs.select do |job|
            job["args"][0] == page.url && job["args"][1] == macro_cluster.id
          end
        expect(matching_jobs.size).to eq(1)
        expect(matching_jobs.first["args"][2]).to eq("This is about the ink")
      end

      it "returns a string (not Halt) to allow the conversation to continue" do
        tool = described_class.new(page)
        result = tool.call(ink_cluster_id: macro_cluster.id, explanation: "Test")

        expect(result).to be_a(String)
        expect(result).not_to be_a(RubyLLM::Tool::Halt)
      end

      it "returns error message when cluster not found" do
        tool = described_class.new(page)
        result = tool.call(ink_cluster_id: 99_999, explanation: "Test")

        expect(result).to include("couldn't find")
        expect(result).to include("99999")
        expect(FetchReviews::SubmitReview.jobs).to be_empty
      end
    end

    describe ReviewFinder::Done do
      it "has the correct name" do
        tool = described_class.new(tool_agent_log)
        expect(tool.name).to eq("done")
      end

      it "has the correct description" do
        tool = described_class.new(tool_agent_log)
        expect(tool.description).to eq("Call this if you are done submitting all reviews")
      end

      it "updates extra_data and halts" do
        tool = described_class.new(tool_agent_log)
        result = tool.call(summary: "No reviews found")

        expect(result).to be_a(RubyLLM::Tool::Halt)
        expect(tool_agent_log.reload.extra_data["summary"]).to eq("No reviews found")
      end
    end

    describe ReviewFinder::Summarize do
      it "has the correct name" do
        tool = described_class.new(unfurler_result, tool_agent_log)
        expect(tool.name).to eq("summarize")
      end

      it "has the correct description" do
        tool = described_class.new(unfurler_result, tool_agent_log)
        expect(tool.description).to eq("Return a summary of the web page")
      end

      it "summarizes non-YouTube pages via WebPageSummarizer" do
        allow(WebPageSummarizer).to receive(:new).with(
          tool_agent_log,
          unfurler_result.raw_html
        ).and_return(double(perform: "This page is about fountain pen ink reviews."))

        tool = described_class.new(unfurler_result, tool_agent_log)
        result = tool.call({})

        expect(result).to eq(
          "Here is a summary of the page:\n\nThis page is about fountain pen ink reviews."
        )
      end

      it "summarizes YouTube videos via YoutubeSummarizer" do
        allow(WebPageSummarizer).to receive(:new)
        allow(YoutubeSummarizer).to receive(:new).with(
          tool_agent_log,
          youtube_unfurler_result
        ).and_return(double(perform: "Reviews Pilot Tsuki-yo."))

        tool = described_class.new(youtube_unfurler_result, tool_agent_log)
        result = tool.call({})

        expect(result).to eq("Here is a summary of the YouTube video:\n\nReviews Pilot Tsuki-yo.")
        expect(WebPageSummarizer).not_to have_received(:new)
      end
    end
  end

  describe "#perform" do
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

      let(:done_after_submit_response) do
        {
          "id" => "chatcmpl-done-after-submit",
          "object" => "chat.completion",
          "created" => 1_677_652_289,
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
                        "summary" => "Submitted review for Pilot Iroshizuku Tsuki-yo."
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
            "completion_tokens" => 30,
            "total_tokens" => 230
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          {
            status: 200,
            body: submit_review_response.to_json,
            headers: {
              "Content-Type" => "application/json"
            }
          },
          {
            status: 200,
            body: done_after_submit_response.to_json,
            headers: {
              "Content-Type" => "application/json"
            }
          }
        )
      end

      it "enqueues review submission job when AI calls submit_review" do
        subject.perform

        matching_jobs =
          FetchReviews::SubmitReview.jobs.select do |job|
            job["args"][0] == page.url && job["args"][1] == macro_cluster.id
          end

        expect(matching_jobs.size).to be >= 1

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

      it "uses correct OpenAI model" do
        subject.perform

        expect(WebMock).to have_requested(:post, openai_url).with(
          body: hash_including(model: "gpt-4.1")
        ).at_least_once
      end

      it "includes tool definitions in the request" do
        subject.perform

        expect(WebMock).to have_requested(:post, openai_url)
          .with { |req|
            body = JSON.parse(req.body)
            tools = body["tools"]
            tool_names = tools.map { |tool| tool["function"]["name"] }
            expect(tool_names).to include("submit_review")
            expect(tool_names).to include("done")
            expect(tool_names).to include("summarize")
            expect(tool_names).to include("ink_similarity_search")
            expect(tool_names).to include("ink_full_text_search")
            true
          }
          .at_least_once
      end

      it "sends page data to OpenAI" do
        subject.perform

        expect(WebMock).to have_requested(:post, openai_url)
          .with { |req|
            body = JSON.parse(req.body)
            text = user_message_text(body)

            expect(text).to include("page data")
            expect(text).to include(page.url)

            true
          }
          .at_least_once
      end

      it "attaches the thumbnail as an image_url part" do
        subject.perform

        expect(WebMock).to have_requested(:post, openai_url)
          .with { |req|
            body = JSON.parse(req.body)
            user_msg = body["messages"].find { |m| m["role"] == "user" }
            parts = user_msg["content"]

            parts.is_a?(Array) &&
              parts.any? do |p|
                p["type"] == "image_url" && p["image_url"]["url"] == unfurler_result.image
              end
          }
          .at_least_once
      end

      context "when ResolveImageUrl returns nil (e.g. broken image link)" do
        before { allow(ResolveImageUrl).to receive(:new).and_return(double(perform: nil)) }

        it "sends no image_url part" do
          subject.perform

          expect(WebMock).to have_requested(:post, openai_url)
            .with { |req|
              body = JSON.parse(req.body)
              user_msg = body["messages"].find { |m| m["role"] == "user" }
              content = user_msg["content"]
              content.is_a?(Array) ? content.none? { |p| p["type"] == "image_url" } : true
            }
            .at_least_once
        end
      end

      context "with a YouTube page" do
        let(:youtube_unfurler_result_with_metadata) do
          Unfurler::Result.new(
            "https://www.youtube.com/watch?v=abc123",
            "YouTube Ink Review",
            "Video review",
            "https://img.youtube.com/vi/abc123/maxresdefault.jpg",
            "Channel",
            "UC123",
            false,
            nil,
            {
              tags: %w[fountain-pen ink-review],
              comments: [{ author: "Eve", text: "Loved this!", like_count: 3 }],
              captions: "Today we review Pilot Tsuki-yo."
            }
          )
        end

        before do
          allow_any_instance_of(Unfurler).to receive(:perform).and_return(
            youtube_unfurler_result_with_metadata
          )
        end

        it "passes through the full YouTube metadata in the prompt JSON" do
          subject.perform

          expect(WebMock).to have_requested(:post, openai_url)
            .with { |req|
              body = JSON.parse(req.body)
              text = user_message_text(body)

              expect(text).to include("fountain-pen")
              expect(text).to include("ink-review")
              expect(text).to include("Loved this!")
              expect(text).to include("Today we review Pilot Tsuki-yo")

              true
            }
            .at_least_once
        end
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

      let(:done_after_multiple_response) do
        {
          "id" => "chatcmpl-done-multiple",
          "object" => "chat.completion",
          "created" => 1_677_652_289,
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
                      "arguments" => { "summary" => "Submitted two reviews." }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 250,
            "completion_tokens" => 20,
            "total_tokens" => 270
          }
        }
      end

      before do
        stub_request(:post, openai_url).to_return(
          {
            status: 200,
            body: multiple_reviews_response.to_json,
            headers: {
              "Content-Type" => "application/json"
            }
          },
          {
            status: 200,
            body: done_after_multiple_response.to_json,
            headers: {
              "Content-Type" => "application/json"
            }
          }
        )
      end

      it "enqueues multiple review submission jobs" do
        subject.perform

        cluster1_jobs =
          FetchReviews::SubmitReview.jobs.select do |job|
            job["args"][0] == page.url && job["args"][1] == macro_cluster.id
          end

        cluster2_jobs =
          FetchReviews::SubmitReview.jobs.select do |job|
            job["args"][0] == page.url && job["args"][1] == cluster2.id
          end

        expect(cluster1_jobs.size).to be >= 1
        expect(cluster2_jobs.size).to be >= 1

        expect(cluster1_jobs.first["args"][2]).to include("Pilot Iroshizuku Tsuki-yo")
        expect(cluster2_jobs.first["args"][2]).to include("Sailor Jentle Yama-dori")
      end
    end

    context "when OpenAI API returns an error" do
      before do
        stub_request(:post, openai_url).to_return(
          status: 500,
          body: { error: { message: "Internal server error" } }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises an error and does not enqueue jobs" do
        initial_job_count = FetchReviews::SubmitReview.jobs.size

        expect { subject.perform }.to raise_error(RubyLLM::ServerError)

        expect(FetchReviews::SubmitReview.jobs.size).to eq(initial_job_count)
      end
    end

    context "when OpenAI returns malformed JSON" do
      before do
        stub_request(:post, openai_url).to_return(
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

  describe "integration scenarios" do
    let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

    let(:done_response) do
      {
        "id" => "chatcmpl-done",
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
                    "arguments" => { "summary" => "Done." }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 20,
          "total_tokens" => 120
        }
      }
    end

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
      end
    end

    context "complete workflow" do
      before do
        stub_request(:post, openai_url).to_return(
          status: 200,
          body: done_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "can be initialized and performed" do
        finder = described_class.new(page)

        expect(finder.agent_log.state).to eq("processing")

        finder.perform

        expect(finder.agent_log.state).to eq("waiting-for-approval")
      end
    end
  end

  describe "error handling" do
    context "when Unfurler raises an error" do
      it "allows the error to propagate during perform" do
        allow_any_instance_of(Unfurler).to receive(:perform).and_raise(
          StandardError,
          "Network error"
        )

        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: "{}",
          headers: {
            "Content-Type" => "application/json"
          }
        )

        expect { subject.perform }.to raise_error(StandardError, "Network error")
      end
    end
  end

  describe "transcript and usage tracking" do
    let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

    let(:done_response) do
      {
        "id" => "chatcmpl-123",
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
                    "arguments" => { "summary" => "Done." }.to_json
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

    before do
      stub_request(:post, openai_url).to_return(
        status: 200,
        body: done_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
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
      expect(usage["model"]).to eq("gpt-4.1")
    end
  end

  describe "transcript restoration" do
    let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

    let(:existing_transcript) do
      [
        { "role" => "developer", "content" => "Your task is to check..." },
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

    let(:done_response) do
      {
        "id" => "chatcmpl-continued",
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
                    "arguments" => { "summary" => "Resuming and finishing." }.to_json
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
      stub_request(:post, openai_url).to_return(
        status: 200,
        body: done_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "restores messages including tool calls from an existing transcript" do
      agent_log =
        page.agent_logs.create!(
          name: "ReviewFinder",
          state: "processing",
          transcript: existing_transcript
        )

      finder = described_class.new(page)
      finder.instance_variable_set(:@agent_log, agent_log)

      finder.perform

      expect(WebMock).to have_requested(:post, openai_url).with { |req|
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

  describe "class constants" do
    it "has correct SYSTEM_DIRECTIVE content" do
      directive = described_class::SYSTEM_DIRECTIVE

      expect(directive).to be_a(String)
      expect(directive.length).to be > 100
      expect(directive).to include("fountain pen inks")
      expect(directive).to include("similarity")
      expect(directive).to include("search")
    end
  end
end
