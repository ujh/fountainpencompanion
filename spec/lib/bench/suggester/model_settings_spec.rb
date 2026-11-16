require_relative "bench_helper"

RSpec.describe Bench::Suggester::ModelSettings do
  def settings(model_id, reasoning_effort: nil)
    described_class.new(model_id, reasoning_effort:)
  end

  it "gives each reasoning model the lowest effort it accepts" do
    expect(
      %w[gpt-5-mini gpt-5-nano-2025-08-07 gpt-5.4-nano gpt-6-luna o4-mini].index_with do |id|
        settings(id).reasoning_effort
      end
    ).to eq(
      "gpt-5-mini" => "minimal",
      "gpt-5-nano-2025-08-07" => "minimal",
      "gpt-5.4-nano" => "none",
      "gpt-6-luna" => "none",
      "o4-mini" => "low"
    )
  end

  it "uses the effort asked for on a reasoning model" do
    expect(settings("gpt-5-mini", reasoning_effort: "low").reasoning_effort).to eq("low")
  end

  it "sends no effort to a model without reasoning, even when one is asked for" do
    model = settings("gpt-4.1-mini", reasoning_effort: "low")

    expect(model).not_to be_reasoning
    expect(model.reasoning_effort).to be_nil
  end

  it "sends temperature 0 without reasoning or at effort none, like the production extractor" do
    expect(
      [
        settings("gpt-4.1-mini"),
        settings("gpt-6-luna"),
        settings("gpt-6-luna", reasoning_effort: "none"),
        settings("gpt-6-luna", reasoning_effort: "low"),
        settings("gpt-5-mini")
      ].map(&:temperature)
    ).to eq([0, 0, 0, nil, nil])
  end

  it "takes the registry's word over the model name" do
    plain =
      RubyLLM::Model.new(id: "gpt-9-plain", provider: "openai", capabilities: %w[function_calling])
    allow(RubyLLM.models).to receive(:find).and_call_original
    allow(RubyLLM.models).to receive(:find).with("gpt-9-plain", provider: "openai").and_return(
      plain
    )

    expect(settings("gpt-9-plain")).not_to be_reasoning
    expect(settings("gpt-9-unregistered")).to be_reasoning
  end
end
