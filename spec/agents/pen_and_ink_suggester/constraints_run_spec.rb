require "rails_helper"

RSpec.describe PenAndInkSuggester do
  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }
  let(:user) { create(:user, confirmed_at: 1.month.ago) }
  let!(:pen) { create(:collected_pen, user:, brand: "Lamy", model: "2000", nib: "B") }
  let!(:bottle) do
    create(:collected_ink, user:, brand_name: "Diamine", ink_name: "Oxblood", kind: "bottle")
  end
  let!(:blue_bottle) do
    create(
      :collected_ink,
      user:,
      brand_name: "Pilot",
      ink_name: "Kon-peki",
      kind: "bottle",
      color: "#1f3fbf"
    )
  end

  def use_constraints(hash)
    allow_any_instance_of(described_class).to receive(:constraints).and_return(
      PenAndInkSuggestion::Constraints.from_h(hash)
    )
  end

  def record_call(id, ink_ref)
    {
      "id" => id,
      "type" => "function",
      "function" => {
        "name" => "record_suggestion",
        "arguments" => { pen_ref: "P1", ink_ref:, reasoning: "A deep, wet red." }.to_json
      }
    }
  end

  def completion(tool_calls)
    {
      "id" => "chatcmpl-1",
      "object" => "chat.completion",
      "model" => "gpt-4.1-mini",
      "choices" => [
        {
          "index" => 0,
          "message" => {
            "role" => "assistant",
            "content" => "",
            "tool_calls" => tool_calls
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

  def ink_ref(body, ink)
    user_message = body["messages"].find { |message| message["role"] == "user" }["content"]
    user_message[/^(I\d+) \| #{Regexp.escape(ink.short_name)} \|/, 1]
  end

  def stub_picks(*inks)
    calls = 0
    stub_request(:post, openai_url).to_return do |request|
      body = JSON.parse(request.body)
      ink = inks.fetch(calls)
      calls += 1
      {
        status: 200,
        body: completion([record_call("call_#{calls}", ink_ref(body, ink))]).to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      }
    end
  end

  def counted_runs
    described_class::DailyCap.new(user).send(:today_usage_count)
  end

  it "records a suggestion from a relaxed side, with the note in the message and the log" do
    use_constraints(ink: { kinds_include: ["sample"] })
    stub_picks(bottle)

    suggester = described_class.new(user, "only samples please")
    response = suggester.perform

    note = "You have no ink samples, so I picked from all your inks."
    expect(response).to include(pen: pen.id, ink: bottle.id)
    expect(response[:message]).to include("_#{note}_")
    expect(suggester.agent_log.extra_data).to include(
      "notes" => [note],
      "relaxations" => [
        { "field" => "ink.kinds_include", "step" => "dropped", "from" => ["sample"] }
      ]
    )
    expect(suggester.agent_log.extra_data).not_to have_key("violations")
  end

  it "rejects a shown pair that breaks a kept constraint and logs the violation" do
    create(
      :currently_inked,
      user:,
      collected_pen: pen,
      collected_ink: bottle,
      archived_on: 1.day.ago
    )
    use_constraints(pair_usage: "new")
    stub_picks(bottle, blue_bottle)

    suggester = described_class.new(user, "a pairing I haven't tried")
    response = suggester.perform

    expect(response).to include(ink: blue_bottle.id)
    expect(suggester.agent_log.extra_data["violations"]).to eq(
      [
        "That pen and ink were inked together before and the user wants a new pairing; " \
          "choose another."
      ]
    )
  end

  context "when an exclusion leaves no ink" do
    before { use_constraints(ink: { exclude_mentions: %w[Diamine], colour_exclude: ["blue"] }) }

    let(:message) do
      "None of your inks is left after excluding \"Diamine\" and blue inks. " \
        "Change your request and try again."
    end

    it "ends with a message naming the exclusions, without an LLM call or a counted run" do
      suggester = described_class.new(user, "no Diamine, nothing blue")
      response = suggester.perform

      expect(response).to eq(message:)
      expect(suggester.agent_log.extra_data).to include("precheck" => "excluded_all")
      expect(WebMock).not_to have_requested(:post, openai_url)
      expect(counted_runs).to eq(0)
    end

    it "counts the run toward the daily cap once the extractor has run" do
      allow_any_instance_of(described_class).to receive(:extractor_ran?).and_return(true)

      suggester = described_class.new(user, "no Diamine, nothing blue")
      response = suggester.perform

      expect(response).to eq(message:)
      expect(suggester.agent_log.extra_data).to include("ended" => "excluded_all")
      expect(suggester.agent_log.extra_data).not_to have_key("precheck")
      expect(counted_runs).to eq(1)
    end
  end

  it "counts the post-resolution end once the extractor has run" do
    create(:currently_inked, user:, collected_pen: pen, collected_ink: bottle)
    allow_any_instance_of(described_class).to receive(:extractor_ran?).and_return(true)

    suggester = described_class.new(user, "something blue")
    suggester.perform

    expect(suggester.agent_log.extra_data).to include("ended" => "no_uninked_or_named_pens")
    expect(counted_runs).to eq(1)
  end

  it "uses the filtered message when every pairing that fits was rejected" do
    use_constraints(ink: { colour_exclude: ["blue"] })

    response =
      described_class.new(
        user,
        "nothing blue",
        [{ "pen_id" => pen.id, "ink_id" => bottle.id }]
      ).perform

    expect(response).to eq(
      message: described_class::FILTERED_END_MESSAGES.fetch(:all_pairs_rejected)
    )
  end

  it "keeps the pen of the newest rejected pair and logs it as a pin" do
    other_pen = create(:collected_pen, user:, brand: "Pilot", model: "Custom 74")
    use_constraints(keep_from_previous: "pen")
    stub_picks(blue_bottle)

    suggester =
      described_class.new(
        user,
        "same pen, another ink",
        [{ "pen_id" => other_pen.id, "ink_id" => bottle.id }]
      )
    response = suggester.perform

    expect(response).to include(pen: other_pen.id, ink: blue_bottle.id)
    expect(suggester.agent_log.extra_data["pins"]).to eq([{ "pen_id" => other_pen.id }])
  end

  it "uses empty constraints in production until the extractor arrives" do
    expect(described_class.new(user, "only samples").send(:constraints)).to eq(
      PenAndInkSuggestion::Constraints.empty
    )
  end
end
