require_relative "bench_helper"

RSpec.describe Bench::Suggester::ModelSettings do
  def settings(model_id, reasoning_effort: nil)
    described_class.new(model_id, reasoning_effort:)
  end

  def registered?(model_id)
    RubyLLM.models.find(model_id, "openai")
    true
  rescue RubyLLM::ModelNotFoundError
    false
  end

  after { RubyLLM.models.all.reject! { |model| model.id.start_with?("gpt-9-") } }

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

  it "sends temperature 0 only to models without reasoning, like the production extractor" do
    expect(
      [
        settings("gpt-4.1-mini"),
        settings("gpt-6-luna"),
        settings("gpt-6-luna", reasoning_effort: "low"),
        settings("gpt-5-mini")
      ].map(&:temperature)
    ).to eq([0, nil, nil, nil])
  end

  it "takes the registry's word over the model name" do
    RubyLLM.models.all << RubyLLM::Model::Info.new(
      id: "gpt-9-plain",
      provider: "openai",
      capabilities: %w[function_calling]
    )

    expect(settings("gpt-9-plain")).not_to be_reasoning
    expect(settings("gpt-9-unregistered")).to be_reasoning
  end

  it "registers a model the registry does not know yet, once" do
    model = settings("gpt-9-new")

    2.times { model.register! }

    expect(RubyLLM.models.all.count { |info| info.id == "gpt-9-new" }).to eq(1)
    expect(RubyLLM.models.find("gpt-9-new", "openai")).to be_reasoning
  end

  it "leaves a known model's registry entry alone" do
    expect { settings("gpt-4.1-mini").register! }.not_to(change { RubyLLM.models.all.size })
    expect(registered?("gpt-4.1-mini")).to be(true)
  end
end
