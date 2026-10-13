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

  it "prices cached prompt tokens at the cached input price, or at list price without the discount" do
    usage = {
      "model" => "gpt-4.1",
      "prompt_tokens" => 3_000,
      "cached_tokens" => 2_000,
      "completion_tokens" => 100
    }

    expect(described_class.cost(usage)).to be_within(1e-9).of(
      (3_000 * 2.0 + 2_000 * 0.5 + 100 * 8.0) / 1e6
    )
    expect(described_class.cost(usage, cache_discount: false)).to be_within(1e-9).of(
      (5_000 * 2.0 + 100 * 8.0) / 1e6
    )
    expect(described_class.total_cost([usage, usage], cache_discount: false)).to be_within(1e-9).of(
      2 * (5_000 * 2.0 + 100 * 8.0) / 1e6
    )
  end

  it "prices cached prompt tokens at each model's own cached input price" do
    usage = {
      "model" => "gpt-6-luna",
      "prompt_tokens" => 1_000,
      "cached_tokens" => 2_000,
      "completion_tokens" => 100
    }

    expect(described_class.cost(usage)).to be_within(1e-12).of(
      (1_000 * 0.10 + 2_000 * 0.01 + 100 * 0.50) / 1e6
    )
  end

  it "prices prompt tokens written to the cache at the cache write price" do
    usage = {
      "model" => "gpt-6-luna-2026-09-22",
      "prompt_tokens" => 3,
      "cache_write_tokens" => 2_000,
      "completion_tokens" => 10
    }

    expect(described_class.cost(usage)).to be_within(1e-12).of(
      (3 * 0.10 + 2_000 * 0.125 + 10 * 0.50) / 1e6
    )
  end

  it "prices cached tokens as cache writes without the discount on a model that charges for writes" do
    usage = { "model" => "gpt-6-luna", "prompt_tokens" => 3, "cached_tokens" => 2_000 }

    expect(described_class.cost(usage, cache_discount: false)).to be_within(1e-12).of(
      (3 * 0.10 + 2_000 * 0.125) / 1e6
    )
  end

  it "prices a fully cached prompt" do
    usage = { "model" => "gpt-4.1-mini", "prompt_tokens" => 0, "cached_tokens" => 1_000 }

    expect(described_class.cost(usage)).to be_within(1e-12).of(1_000 * 0.10 / 1e6)
  end

  it "does not confuse gpt-4.1 with gpt-4.1-mini" do
    expect(described_class.price_for("gpt-4.1-2025-04-14")).to include(input: 2.00, output: 8.00)
    expect(described_class.price_for("gpt-4.1-mini")).to include(input: 0.40, output: 1.60)
    expect(described_class.price_for("gpt-4.10")).to be_nil
  end

  it "does not confuse gpt-5-mini with gpt-5.4-mini" do
    expect(described_class.price_for("gpt-5-mini-2025-08-07")).to include(input: 0.25)
    expect(described_class.price_for("gpt-5.4-mini-2026-03-17")).to include(input: 0.75)
    expect(described_class.price_for("gpt-5")).to be_nil
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
