require "rails_helper"

RSpec.describe PenAndInkSuggester do
  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }
  let(:user) { create(:user) }
  let!(:pen) { create(:collected_pen, user:, brand: "Pilot", model: "Custom 74", nib: "M") }
  let!(:ink) do
    create(:collected_ink, user:, brand_name: "Pilot", ink_name: "Kon-peki", kind: "bottle")
  end

  def record_call(id = "call_1", pen_ref: "P1", ink_ref: "I1", reasoning: "A calm, wet blue.")
    {
      "id" => id,
      "type" => "function",
      "function" => {
        "name" => "record_suggestion",
        "arguments" => { pen_ref:, ink_ref:, reasoning: }.to_json
      }
    }
  end

  def invalid_calls(count, first: 0)
    count.times.map { |i| record_call("call_#{first + i}", pen_ref: "P9") }
  end

  def completion(tool_calls: nil, content: "")
    message = { "role" => "assistant", "content" => content }
    message["tool_calls"] = tool_calls if tool_calls
    {
      "id" => "chatcmpl-1",
      "object" => "chat.completion",
      "model" => "gpt-4.1-mini",
      "choices" => [
        {
          "index" => 0,
          "message" => message,
          "finish_reason" => tool_calls ? "tool_calls" : "stop"
        }
      ],
      "usage" => {
        "prompt_tokens" => 150,
        "completion_tokens" => 50,
        "total_tokens" => 200
      }
    }
  end

  def stub_completions(*bodies)
    stub_request(:post, openai_url).to_return(
      *bodies.map do |body|
        { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
      end
    )
  end

  def stub_pick(**arguments)
    stub_completions(completion(tool_calls: [record_call(**arguments)]))
  end

  describe "the model" do
    before { stub_pick }

    it "is the mini model for free users" do
      described_class.new(user).perform

      expect(WebMock).to have_requested(:post, openai_url).with(
        body: hash_including("model" => "gpt-4.1-mini")
      )
    end

    it "is the full model for patrons" do
      user.update!(patron: true)

      described_class.new(user).perform

      expect(WebMock).to have_requested(:post, openai_url).with(
        body: hash_including("model" => "gpt-4.1")
      )
    end

    it "is the full model for admins" do
      user.update!(admin: true)

      described_class.new(user).perform

      expect(WebMock).to have_requested(:post, openai_url).with(
        body: hash_including("model" => "gpt-4.1")
      )
    end
  end

  describe "precheck" do
    it "answers without an LLM call when there are no active pens" do
      pen.archive!

      response = described_class.new(user).perform

      expect(response).to eq(message: described_class::NO_UNINKED_PENS_MESSAGE)
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "answers without an LLM call when the only inks are swabs" do
      ink.update!(kind: "swab")

      response = described_class.new(user).perform

      expect(response).to eq(message: described_class::NO_FILLABLE_INKS_MESSAGE)
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "answers without an LLM call when there are no active inks" do
      ink.archive!

      response = described_class.new(user).perform

      expect(response).to eq(message: described_class::NO_FILLABLE_INKS_MESSAGE)
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "treats an ink without a kind as fillable" do
      ink.update!(kind: "swab")
      unknown_kind = create(:collected_ink, user:, kind: nil)
      stub_pick

      response = described_class.new(user).perform

      expect(response[:ink]).to eq(unknown_kind.id)
    end

    it "marks the agent log with the precheck reason" do
      ink.update!(kind: "swab")
      suggester = described_class.new(user)

      suggester.perform

      expect(suggester.agent_log.extra_data).to eq(
        "message" => described_class::NO_FILLABLE_INKS_MESSAGE,
        "precheck" => "no_fillable_inks"
      )
      expect(suggester.agent_log.state).to eq("waiting-for-approval")
    end

    it "does not count precheck runs toward the daily cap" do
      ink.update!(kind: "swab")
      described_class::MAX_PER_DAY.times { described_class.new(user).perform }
      ink.update!(kind: "bottle")
      stub_pick

      response = described_class.new(user).perform

      expect(response[:ink]).to eq(ink.id)
      expect(WebMock).to have_requested(:post, openai_url).once
    end
  end

  describe "daily cap" do
    before { stub_pick }

    def create_logs(count)
      create_list(:agent_log, count, name: described_class.name, owner: user)
    end

    it "allows the 20th run of the day for free users" do
      create_logs(19)

      described_class.new(user).perform

      expect(WebMock).to have_requested(:post, openai_url).once
    end

    it "stops free users after 20 runs a day" do
      create_logs(20)

      response = described_class.new(user).perform

      expect(response[:message]).to include("daily limit of 20 suggestions", "Patron")
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "stops patrons after 50 runs a day" do
      user.update!(patron: true)
      create_logs(49)
      described_class.new(user).perform

      response = described_class.new(user).perform

      expect(response[:message]).to eq(
        "You have reached your daily limit of 50 suggestions. Please try again tomorrow."
      )
      expect(WebMock).to have_requested(:post, openai_url).once
    end

    it "skips the cap when enforce_daily_limit is false" do
      create_logs(20)

      response = described_class.new(user, enforce_daily_limit: false).perform

      expect(response[:ink]).to eq(ink.id)
      expect(WebMock).to have_requested(:post, openai_url).once
    end
  end

  describe "agent log per request" do
    before { stub_pick }

    it "does not reuse a stale processing log" do
      stale =
        create(
          :agent_log,
          name: described_class.name,
          owner: user,
          state: AgentLog::PROCESSING,
          transcript: [{ "role" => "user", "content" => "Stale prompt from an earlier run" }]
        )
      suggester = described_class.new(user)

      suggester.perform

      expect(suggester.agent_log).not_to eq(stale)
      expect(stale.reload.state).to eq(AgentLog::PROCESSING)
      expect(WebMock).not_to have_requested(:post, openai_url).with(
        body: /Stale prompt from an earlier run/
      )
    end

    it "creates a new log for every run" do
      expect {
        described_class.new(user).perform
        described_class.new(user).perform
      }.to change { user.agent_logs.where(name: described_class.name).count }.by(2)
    end
  end

  describe "tool-call limit" do
    it "returns the error result when the limit is exceeded without a valid call" do
      stub_completions(completion(tool_calls: invalid_calls(13)))
      suggester = described_class.new(user)

      response = suggester.perform

      expect(response).to eq(described_class.error_result)
      expect(suggester.agent_log.extra_data["error"]).to eq("ToolCallLimitExceeded")
      expect(WebMock).to have_requested(:post, openai_url).once
    end

    it "allows 12 tool calls" do
      stub_completions(
        completion(tool_calls: invalid_calls(11) + [record_call("call_11", reasoning: "Twelfth")])
      )
      suggester = described_class.new(user)

      response = suggester.perform

      expect(response).to include(ink: ink.id, pen: pen.id)
      expect(response[:message]).to end_with("Twelfth")
      expect(suggester.agent_log.extra_data).not_to have_key("error")
    end

    it "returns the recorded suggestion when the limit is exceeded after a valid call" do
      stub_completions(
        completion(
          tool_calls: [record_call("call_0", reasoning: "Recorded")] + invalid_calls(12, first: 1)
        )
      )
      suggester = described_class.new(user)

      response = suggester.perform

      expect(response).to include(ink: ink.id, pen: pen.id)
      expect(response[:message]).to end_with("Recorded")
      expect(suggester.agent_log.extra_data["error"]).to eq("ToolCallLimitExceeded")
    end
  end

  describe "API errors" do
    it "raises a server error on a 500" do
      stub_request(:post, openai_url).to_return(
        status: 500,
        body: { error: { message: "Internal server error" } }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      expect { described_class.new(user).perform }.to raise_error(RubyLLM::ServerError)
    end

    it "raises a parsing error on malformed JSON" do
      stub_request(:post, openai_url).to_return(
        status: 200,
        body: "invalid json",
        headers: {
          "Content-Type" => "application/json"
        }
      )

      expect { described_class.new(user).perform }.to raise_error(Faraday::ParsingError)
    end
  end

  describe "transcript and usage" do
    before { stub_pick }

    it "saves the transcript" do
      suggester = described_class.new(user)

      suggester.perform

      expect(suggester.agent_log.transcript.map { |entry| entry["role"] }).to eq(
        %w[system user assistant tool]
      )
    end

    it "saves the run when the pick's tool-call arguments and text contain NUL" do
      stub_completions(
        completion(
          tool_calls: [record_call(reasoning: "A calm, wet bl\u0000ue.")],
          content: "Pick\u0000ing."
        )
      )
      suggester = described_class.new(user)

      response = suggester.perform

      log = suggester.agent_log.reload
      expect(response).to include(pen: pen.id, ink: ink.id)
      expect(response[:message]).to end_with("A calm, wet blue.")
      expect(log.state).to eq(AgentLog::WAITING_FOR_APPROVAL)
      expect(log.extra_data).to include(
        "pen" => pen.id,
        "ink" => ink.id,
        "reasoning" => "A calm, wet blue."
      )
      expect(log.transcript.to_json).not_to include("\\u0000")
      expect(log.transcript.map { |entry| entry["content"] }).to include("Picking.")
    end

    it "saves the usage" do
      suggester = described_class.new(user)

      suggester.perform

      expect(suggester.agent_log.usage).to include(
        "prompt_tokens" => 150,
        "completion_tokens" => 50,
        "total_tokens" => 200,
        "model" => "gpt-4.1-mini"
      )
    end
  end

  describe "query count" do
    def grow_collection(size)
      pens = create_list(:collected_pen, size, user:)
      inks = create_list(:collected_ink, size, user:, kind: "bottle")
      pens
        .zip(inks)
        .each_with_index do |(collected_pen, collected_ink), i|
          create(
            :currently_inked,
            user:,
            collected_pen:,
            collected_ink:,
            inked_on: 20.days.ago,
            archived_on: i.even? ? 10.days.ago : nil
          )
        end
    end

    def run_queries
      count = 0
      counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        described_class.new(user, seed: 1).perform
      end
      count
    end

    it "is the same for a small collection and one larger than the slices" do
      stub_pick
      grow_collection(3)
      small = run_queries

      grow_collection(60)
      large = run_queries

      expect(large).to eq(small)
    end
  end
end
