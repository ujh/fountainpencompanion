require "rails_helper"

RSpec.describe PenAndInkSuggester do
  include ConstraintExtractorHelpers

  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }
  let(:user) { create(:user, confirmed_at: 1.month.ago) }
  let!(:heron) do
    create(:collected_pen, user:, brand: "Corvid", model: "Heron", color: "Moss Lagoon", nib: "F")
  end
  let!(:harbour_fog) do
    create(:collected_ink, user:, brand_name: "Quillworth", ink_name: "Harbour Fog", kind: "bottle")
  end
  let!(:ember) do
    create(:collected_ink, user:, brand_name: "Wrenfield", ink_name: "Ember", kind: "bottle")
  end

  def not_found(text)
    "I couldn't find \"#{text}\" in your collection."
  end

  def pick_completion(pen_ref, ink_ref)
    arguments = { pen_ref:, ink_ref:, reasoning: "A fine pairing." }
    {
      "id" => "chatcmpl-pick",
      "object" => "chat.completion",
      "model" => "gpt-4.1-mini",
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
                  "arguments" => arguments.to_json
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => {
        "prompt_tokens" => 10,
        "completion_tokens" => 5,
        "total_tokens" => 15
      }
    }
  end

  def user_message(request)
    JSON.parse(request.body)["messages"].reverse.find { |message| message["role"] == "user" }[
      "content"
    ]
  end

  def ref_for(message, name)
    message[/^([PI]\d+)\b[^|\n]*\| #{Regexp.escape(name)}\b/, 1]
  end

  def stub_pick(pen:, ink:)
    stub_request(:post, openai_url).to_return do |request|
      message = user_message(request)
      body = pick_completion(ref_for(message, pen), ref_for(message, ink))
      { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
    end
  end

  def pick_message
    message = nil
    expect(WebMock).to have_requested(:post, openai_url)
      .with { |request|
        message = user_message(request)
        true
      }
      .once
    message
  end

  def suggest(constraints, pen:, ink:)
    stub_constraint_extractor(constraints)
    stub_pick(pen:, ink:)
    suggester = described_class.new(user, "an instruction")
    [suggester.perform, suggester.agent_log.reload.extra_data]
  end

  it "drops the note when a pen's colour, given as an ink, names the picked pen" do
    response, extra_data =
      suggest({ ink: { mentions: ["Moss Lagoon"] } }, pen: "Corvid Heron", ink: "Wrenfield Ember")

    expect(response).to include(pen: heron.id, ink: ember.id)
    expect(response[:message]).not_to include("couldn't find")
    expect(extra_data).to include("notes" => [], "dropped_notes" => [not_found("Moss Lagoon")])
    expect(pick_message).to include("SERVER NOTES (already shown): #{not_found("Moss Lagoon")}")
  end

  it "drops the note when a bare lower-case brand on the wrong side is the picked ink's brand" do
    response, extra_data =
      suggest(
        { pen: { mentions: ["quillworth"] } },
        pen: "Corvid Heron",
        ink: "Quillworth Harbour Fog"
      )

    expect(response).to include(ink: harbour_fog.id)
    expect(response[:message]).not_to include("couldn't find")
    expect(extra_data).to include("notes" => [], "dropped_notes" => [not_found("quillworth")])
  end

  it "keeps the note when the pick doesn't match the mention" do
    response, extra_data =
      suggest({ pen: { mentions: ["quillworth"] } }, pen: "Corvid Heron", ink: "Wrenfield Ember")

    expect(response[:message]).to include("_#{not_found("quillworth")}_")
    expect(extra_data["notes"]).to eq([not_found("quillworth")])
    expect(extra_data).not_to have_key("dropped_notes")
  end

  it "keeps the notes of the other mentions" do
    response, extra_data =
      suggest(
        { ink: { mentions: ["Moss Lagoon", "Saltmarsh Grey"] } },
        pen: "Corvid Heron",
        ink: "Quillworth Harbour Fog"
      )

    expect(response[:message]).to include("_#{not_found("Saltmarsh Grey")}_")
    expect(response[:message]).not_to include(not_found("Moss Lagoon"))
    expect(extra_data).to include(
      "notes" => [not_found("Saltmarsh Grey")],
      "dropped_notes" => [not_found("Moss Lagoon")]
    )
  end
end
