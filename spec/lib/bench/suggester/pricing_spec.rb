require_relative "bench_helper"

RSpec.describe Bench::Suggester::Pricing do
  it "prices a dated model id with the list price of its family" do
    usage = {
      "model" => "gpt-4.1-mini-2025-04-14",
      "prompt_tokens" => 5_900,
      "completion_tokens" => 159
    }

    expect(described_class.cost(usage)).to be_within(1e-9).of((5_900 * 0.40 + 159 * 1.60) / 1e6)
  end

  it "does not confuse gpt-4.1 with gpt-4.1-mini" do
    expect(described_class.price_for("gpt-4.1-2025-04-14")).to eq({ input: 2.00, output: 8.00 })
    expect(described_class.price_for("gpt-4.1-mini")).to eq({ input: 0.40, output: 1.60 })
    expect(described_class.price_for("gpt-4.10")).to be_nil
  end

  it "costs nothing without tokens and nil for an unknown model" do
    expect(described_class.cost({ "prompt_tokens" => 0, "completion_tokens" => 0 })).to eq(0.0)
    expect(described_class.cost({ "model" => "llama", "prompt_tokens" => 10 })).to be_nil
  end

  it "sums the usage of a run and its sub-agents" do
    usages = [
      { "model" => "gpt-4.1", "prompt_tokens" => 1_000_000, "completion_tokens" => 0 },
      { model: "gpt-4.1-mini", prompt_tokens: 0, completion_tokens: 1_000_000 }
    ]

    expect(described_class.total_cost(usages)).to be_within(1e-9).of(3.60)
    expect(
      described_class.total_cost([*usages, { "model" => "llama", "prompt_tokens" => 1 }])
    ).to be_nil
  end
end
