require "rails_helper"

RSpec.describe PenAndInkSuggester do
  include ConstraintExtractorHelpers

  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }
  let(:user) { create(:user, confirmed_at: 1.month.ago) }
  let!(:lamy) do
    create(:collected_pen, user:, brand: "Lamy", model: "2000", color: "Black", nib: "B")
  end
  let!(:safari) do
    create(:collected_pen, user:, brand: "Lamy", model: "Safari", color: "Yellow", nib: "F")
  end
  let!(:custom) { create(:collected_pen, user:, brand: "Pilot", model: "Custom 74", nib: "M") }
  let!(:oxblood) do
    create(:collected_ink, user:, brand_name: "Diamine", ink_name: "Oxblood", kind: "sample")
  end
  let!(:kon_peki) do
    create(
      :collected_ink,
      user:,
      brand_name: "Pilot",
      line_name: "Iroshizuku",
      ink_name: "Kon-peki",
      kind: "bottle"
    )
  end
  let(:samples_and_broad_nibs) do
    {
      soft_notes: "wants to use up samples",
      pen: {
        nib_width: "broadish"
      },
      ink: {
        kinds_include: ["sample"]
      }
    }
  end

  def json_response(body, status: 200)
    { status:, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  def pick_completion
    {
      "id" => "chatcmpl-pick",
      "object" => "chat.completion",
      "model" => "gpt-4.1-mini-2025-04-14",
      "choices" => [
        {
          "index" => 0,
          "message" => {
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              {
                "id" => "call_pick",
                "type" => "function",
                "function" => {
                  "name" => "record_suggestion",
                  "arguments" => {
                    pen_ref: "P1",
                    ink_ref: "I1",
                    reasoning: "A fine pairing."
                  }.to_json
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => {
        "prompt_tokens" => 3_000,
        "completion_tokens" => 80,
        "total_tokens" => 3_080
      }
    }
  end

  def stub_llm(constraints = {}, &extractor_response)
    extractor_response ||= ->(_request) { json_response(set_constraints_completion(constraints)) }
    stub_request(:post, openai_url).to_return do |request|
      if extractor_request?(request)
        extractor_response.call(request)
      else
        json_response(pick_completion)
      end
    end
  end

  def requests(extractor:)
    bodies = []
    expect(WebMock).to have_requested(:post, openai_url)
      .with { |request|
        bodies << JSON.parse(request.body) if extractor_request?(request) == extractor
        true
      }
      .at_least_once
    bodies
  end

  def last_user_message(body)
    body["messages"].reverse.find { |message| message["role"] == "user" }["content"]
  end

  def pick_message
    last_user_message(requests(extractor: false).sole)
  end

  def counted_runs
    described_class::DailyCap.new(user).send(:today_usage_count)
  end

  describe "when the extractor reads the request" do
    it "sends only the pens and inks that fit, with the wishes, and logs the constraints" do
      stub_llm(samples_and_broad_nibs)

      suggester =
        described_class.new(user, "only ink samples, I want to use them up, and fairly broad nibs")
      response = suggester.perform

      expect(response).to include(pen: lamy.id, ink: oxblood.id)
      expect(pick_message).to include(
        "PENS (1 of 1 that fit: broad-ish nibs)\nP1 | Lamy 2000",
        "INKS (1 of 1 that fit: ink samples)\nI1 | Diamine Oxblood",
        "WISHES (read from the request): wants to use up samples\n<request>"
      )
      expect(pick_message).not_to include("UNFILTERED")
      expect(suggester.agent_log.extra_data).to include(
        "constraints" => PenAndInkSuggestion::Constraints.from_h(samples_and_broad_nibs).to_h,
        "constraints_source" => "extractor",
        "mentions" => []
      )
      expect(suggester.agent_log.extra_data).not_to have_key("extractor_error")
    end

    it "asks the extractor before the pick and keeps its transcript and usage in a child log" do
      stub_llm(samples_and_broad_nibs)

      suggester = described_class.new(user, "only samples, fairly broad nibs")
      suggester.perform

      child = suggester.agent_log.agent_logs.sole
      expect(child).to have_attributes(name: PenAndInkConstraintExtractor.name)
      expect(child.usage).to include("prompt_tokens" => 1_000)
      expect(child.transcript.last).to include("role" => "tool")
      expect(suggester.agent_log.usage).to include("prompt_tokens" => 3_000)
      expect(suggester.agent_log.transcript.to_json).not_to include("set_constraints")
    end

    it "counts the run once toward the daily cap" do
      stub_llm(samples_and_broad_nibs)

      described_class.new(user, "only samples").perform

      expect(counted_runs).to eq(1)
    end

    it "keeps the pen of the turned-down suggestion when the extractor reads that wish" do
      stub_llm(keep_from_previous: "pen")

      suggester =
        described_class.new(
          user,
          "same pen, another ink",
          [{ "pen_id" => lamy.id, "ink_id" => oxblood.id }]
        )
      suggester.perform

      expect(last_user_message(requests(extractor: false).first)).to include(
        "PENS (★ requested)\nP1 ★ | Lamy 2000"
      )
      expect(suggester.agent_log.extra_data["pins"]).to eq([{ "pen_id" => lamy.id }])
      expect(last_user_message(requests(extractor: true).sole)).to eq(
        "<request>same pen, another ink</request>"
      )
    end

    it "ignores keep_from_previous when no suggestion was turned down" do
      stub_llm(keep_from_previous: "pen")

      suggester = described_class.new(user, "same pen, another ink")
      suggester.perform

      expect(pick_message).to include("PENS (3 of 3 uninked)")
      expect(suggester.agent_log.extra_data["constraints"]).to include(
        "keep_from_previous" => "none"
      )
    end

    it "resolves a mention the extractor put on the wrong side" do
      stub_llm(pen: { mentions: ["Kon-peki"] })

      suggester = described_class.new(user, "use Kon-peki")
      suggester.perform

      expect(pick_message).to include("INKS (★ requested)\nI1 ★ | Pilot Iroshizuku Kon-peki")
      expect(suggester.agent_log.extra_data["pins"]).to eq([{ "ink_id" => kon_peki.id }])
    end

    it "keeps every ink when a pen brand the user has no pens of names an ink brand" do
      stub_llm(pen: { mentions: ["Diamine"] })

      suggester = described_class.new(user, "a Diamine pen")
      suggester.perform

      expect(pick_message).to include("Diamine Oxblood", "Pilot Iroshizuku Kon-peki")
      expect(suggester.agent_log.extra_data["pins"]).to eq([])
      expect(suggester.agent_log.extra_data["notes"]).to include(
        "I couldn't find \"Diamine\" in your collection."
      )
    end

    it "pins the items the extractor names" do
      stub_llm(pen: { mentions: ["Lamy 2000"] })

      suggester = described_class.new(user, "an ink for my Lamy 2000")
      suggester.perform

      expect(pick_message).to include("PENS (★ requested)\nP1 ★ | Lamy 2000")
      expect(pick_message).not_to include("Safari")
      expect(suggester.agent_log.extra_data).to include(
        "mentions" => [{ "text" => "Lamy 2000", "side" => "pen" }],
        "pins" => [{ "pen_id" => lamy.id }]
      )
    end

    it "drops the Ruby matcher's pins when the extractor names nothing" do
      stub_llm(soft_notes: "an ink like the one in the Lamy 2000")

      suggester = described_class.new(user, "an ink like the one in my Lamy 2000")
      suggester.perform

      expect(pick_message).to include("PENS (3 of 3 uninked)")
      expect(suggester.agent_log.extra_data["pins"]).to eq([])
    end

    it "follows the extractor when it names only the brand of a pen the matcher found" do
      stub_llm(pen: { mentions: ["Lamy"] })

      suggester = described_class.new(user, "a Lamy that writes like my Lamy 2000")
      suggester.perform

      expect(last_user_message(requests(extractor: true).sole)).to include("pen: Lamy 2000")
      expect(pick_message).to include("PENS (2 of 2 uninked)")
      expect(pick_message).not_to include("Custom 74")
      expect(suggester.agent_log.extra_data["pins"]).to eq([])
    end

    it "sends the names the matcher found in the collection to the extractor" do
      stub_llm(pen: { mentions: ["Lamy 2000"] })

      described_class.new(user, "my lamy 2000 with kon-peki").perform

      expect(last_user_message(requests(extractor: true).sole)).to eq(
        "<request>my lamy 2000 with kon-peki</request>\n<names_found>\n" \
          "pen: lamy 2000\nink: kon-peki (Pilot Iroshizuku Kon-peki)\n</names_found>"
      )
    end

    it "sends only the request when the matcher finds no name" do
      stub_llm(ink: { colour_include: ["blue"] })

      described_class.new(user, "something blue").perform

      expect(last_user_message(requests(extractor: true).sole)).to eq(
        "<request>something blue</request>"
      )
    end

    describe "a pen named without its brand" do
      let!(:halcyon) do
        create(:collected_pen, user:, brand: "Corvid", model: "Halcyon Slim Asymmetry", nib: "F")
      end

      it "pins it when the extractor takes the found name, even when it is inked" do
        [lamy, safari, custom, halcyon].each do |pen|
          create(:currently_inked, user:, collected_pen: pen, collected_ink: kon_peki)
        end
        inking = halcyon.currently_inkeds.sole
        stub_llm(pen: { mentions: ["Corvid Halcyon Slim Asymmetry"] })

        suggester = described_class.new(user, "Pick me an ink for the Halcyon Slim Asymmetry")
        response = suggester.perform

        expect(last_user_message(requests(extractor: true).sole)).to include(
          "<names_found>\npen: Halcyon Slim Asymmetry (Corvid Halcyon Slim Asymmetry)\n"
        )
        expect(response).to include(
          pen: halcyon.id,
          pen_currently_inked: true,
          currently_inked_id: inking.id
        )
        expect(suggester.agent_log.extra_data["pins"]).to eq([{ "pen_id" => halcyon.id }])
      end

      it "pins nothing when the extractor reads the found name as ruled out" do
        stub_llm(pen: { exclude_mentions: ["Halcyon Slim Asymmetry"] })

        suggester =
          described_class.new(user, "an ink for the Halcyon Slim Asymmetry, no wait, not that one")
        suggester.perform

        expect(last_user_message(requests(extractor: true).sole)).to include(
          "pen: Halcyon Slim Asymmetry (Corvid Halcyon Slim Asymmetry)"
        )
        expect(suggester.agent_log.extra_data["pins"]).to eq([])
        expect(pick_message).to include("PENS (3 of 3 that fit")
        expect(pick_message).not_to include("| Corvid Halcyon")
      end
    end

    it "uses the brand the extractor names as a filter when the matcher pins nothing" do
      stub_llm(pen: { mentions: ["Lamy"] })

      described_class.new(user, "one of my Lamys").perform

      expect(pick_message).to include("PENS (2 of 2 uninked)")
      expect(pick_message).not_to include("Custom 74")
    end
  end

  it "makes no extractor call when the precheck ends the run" do
    user.collected_inks.destroy_all

    described_class.new(user, "only samples").perform

    expect(WebMock).not_to have_requested(:post, openai_url)
  end

  it "makes no extractor call for a run without an instruction" do
    stub_llm

    described_class.new(user).perform

    expect(WebMock).to have_requested(:post, openai_url).once
    expect(requests(extractor: true)).to be_empty
  end

  describe "when the extractor fails" do
    shared_examples "a fallback run" do |error_class|
      it "falls back to the unfiltered lists and the Ruby pins, logging #{error_class}" do
        suggester = described_class.new(user, "an ink for my Lamy 2000, only samples")
        response = suggester.perform

        expect(response).to include(pen: lamy.id)
        expect(pick_message).to include(
          "PENS (★ requested)\nP1 ★ | Lamy 2000",
          "INKS UNFILTERED (2 of 2)"
        )
        expect(suggester.agent_log.extra_data).to include(
          "constraints" => nil,
          "constraints_source" => "fallback",
          "extractor_error" => error_class,
          "pins" => [{ "pen_id" => lamy.id }]
        )
        expect(counted_runs).to eq(1)
      end
    end

    {
      429 => "RubyLLM::RateLimitError",
      400 => "RubyLLM::BadRequestError",
      500 => "RubyLLM::ServerError"
    }.each do |status, error_class|
      context "with a #{status} answer" do
        before { stub_llm { json_response({ error: { message: "nope" } }, status:) } }

        it_behaves_like "a fallback run", error_class
      end
    end

    context "with a timeout" do
      before { stub_llm { raise Faraday::TimeoutError } }

      it_behaves_like "a fallback run", "Faraday::TimeoutError"
    end

    context "with malformed JSON" do
      before do
        stub_llm do
          { status: 200, body: "{not json", headers: { "Content-Type" => "application/json" } }
        end
      end

      it_behaves_like "a fallback run", "Faraday::ParsingError"
    end

    context "when the model sends tool-call arguments that aren't JSON" do
      before { stub_llm { json_response(set_constraints_completion(arguments_json: "{")) } }

      it_behaves_like "a fallback run", "JSON::ParserError"
    end

    context "when the model never calls set_constraints" do
      before do
        stub_llm do
          completion = set_constraints_completion
          completion["choices"].first["message"] = { "role" => "assistant", "content" => "Hi." }
          completion["choices"].first["finish_reason"] = "stop"
          json_response(completion)
        end
      end

      it_behaves_like "a fallback run", "RubyLlmAgent::DecisionNotReachedError"
    end

    context "when the model keeps calling set_constraints with invalid JSON" do
      around do |example|
        previous = Rails.configuration.x.pen_and_ink_constraint_extractor_params
        Rails.configuration.x.pen_and_ink_constraint_extractor_params = "json"
        example.run
      ensure
        Rails.configuration.x.pen_and_ink_constraint_extractor_params = previous
      end

      before { stub_llm { json_response(set_constraints_completion({ constraints_json: "{" })) } }

      it_behaves_like "a fallback run", "RubyLlmAgent::ToolCallLimitExceeded"
    end

    context "without an API key" do
      before do
        allow_any_instance_of(PenAndInkConstraintExtractor).to receive(:access_token).and_return(
          nil
        )
        stub_llm
      end

      it_behaves_like "a fallback run", "RubyLLM::ConfigurationError"
    end

    context "with an unknown model id" do
      before do
        allow_any_instance_of(PenAndInkConstraintExtractor).to receive(:model_id).and_return(
          "gpt-unknown"
        )
        stub_llm
      end

      it_behaves_like "a fallback run", "RubyLLM::ModelNotFoundError"
    end

    it "sends today's tier slices" do
      create_list(:collected_pen, 60, user:)
      create_list(:collected_ink, 60, user:)
      stub_llm { json_response({ error: { message: "down" } }, status: 500) }

      described_class.new(user, "something red").perform

      expect(pick_message).to include(
        "PENS UNFILTERED (50 of 63 uninked)",
        "INKS UNFILTERED (50 of 62)"
      )
    end
  end
end
