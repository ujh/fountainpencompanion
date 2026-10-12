require_relative "bench_helper"

RSpec.describe Bench::Suggester::ExtractorScore do
  def label(text, constraints = {}, split: "dev", ambiguous: false, reviewed: false)
    Bench::Suggester::ExtractorLabel.from_h(
      { "text" => text, "constraints" => constraints, "split" => split, ambiguous:, reviewed: }
    )
  end

  def prediction(constraints = {}, error: nil)
    { "constraints" => error ? nil : constraints, "error" => error }
  end

  def score(labels, predictions)
    described_class.new(labels:, predictions:)
  end

  def row(text, constraints, predicted)
    score([label(text, constraints)], { text => prediction(predicted) }).rows.sole
  end

  it "counts true positives, false positives and misses per field" do
    scored =
      row(
        "red or orange samples, F nib",
        {
          "pen" => {
            "nib_grades_include" => ["F"]
          },
          "ink" => {
            "colour_include" => %w[red orange]
          }
        },
        { "pen" => { "nib_grades_include" => %w[F M] }, "ink" => { "colour_include" => ["red"] } }
      )

    expect(scored["fields"]["pen.nib_grades_include"]).to eq(
      "tp" => ["F"],
      "fp" => ["M"],
      "fn" => []
    )
    expect(scored["fields"]["ink.colour_include"]).to eq(
      "tp" => ["red"],
      "fp" => [],
      "fn" => ["orange"]
    )
    expect(scored["hard_false_positives"]).to eq(["pen.nib_grades_include"])
  end

  it "scores enum fields only when they leave their default" do
    scored = row("a pen I never used", { "pen" => { "usage" => "never_used" } }, {})

    expect(scored["fields"]["pen.usage"]).to eq("tp" => [], "fp" => [], "fn" => ["never_used"])
    expect(scored["fields"]["ink.usage"]).to eq("tp" => [], "fp" => [], "fn" => [])
    expect(scored["hard_false_positives"]).to be_empty
  end

  it "matches mentions by their words, allowing a shorter form and a typo" do
    scored =
      row(
        "ink for my Pilot Custom 74 and Pelikan M200",
        { "pen" => { "mentions" => ["Pilot Custom 74", "Pelikan M200"] } },
        { "pen" => { "mentions" => ["Custom 74", "Pelican M200", "Safari"] } }
      )

    expect(scored["fields"]["pen.mentions"]).to eq(
      "tp" => ["Custom 74", "Pelican M200"],
      "fp" => ["Safari"],
      "fn" => []
    )
  end

  it "counts a false positive on a side the label names apart from the other sides" do
    scored =
      row(
        "Lamy 2000, F",
        { "pen" => { "mentions" => ["Lamy 2000"] } },
        {
          "pen" => {
            "mentions" => ["Lamy 2000"],
            "nib_grades_include" => ["F"]
          },
          "pair_usage" => "new"
        }
      )

    expect(scored["hard_false_positives"]).to eq(%w[pair_usage pen.nib_grades_include])
    expect(scored["hard_false_positives_off_named_sides"]).to eq(["pair_usage"])
  end

  it "always counts a false mention, even on a named side" do
    scored =
      row(
        "Lamy 2000",
        { "pen" => { "mentions" => ["Lamy 2000"] } },
        { "pen" => { "mentions" => ["Lamy 2000", "Safari"] } }
      )

    expect(scored["hard_false_positives_off_named_sides"]).to eq(["pen.mentions"])
  end

  it "leaves ambiguous labels and failed extractions out of the rates" do
    labels = [
      label("only samples", { "ink" => { "kinds_include" => ["sample"] } }),
      label("blue maybe", {}, ambiguous: true),
      label("anything", {}),
      label("something red", { "ink" => { "colour_include" => ["red"] } }, split: "test")
    ]
    predictions = {
      "only samples" => prediction({ "ink" => { "kinds_include" => ["sample"] } }),
      "blue maybe" => prediction({ "ink" => { "colour_include" => ["blue"] } }),
      "anything" => prediction(error: "RubyLLM::ServerError"),
      "something red" => prediction({ "ink" => { "colour_include" => %w[red pink] } })
    }

    summary = score(labels, predictions).summary

    expect(summary).to include(
      "strings" => 4,
      "errors" => 1,
      "scored" => 2,
      "with_hard_false_positive" => 1,
      "hard_false_positive_rate" => 0.5,
      "hard_false_positive_rate_off_named_sides" => 0.5,
      "gate" => 0.03
    )
    expect(summary["fields"]["ink.colour_include"]).to include(
      "tp" => 1,
      "fp" => 1,
      "fn" => 0,
      "precision" => 0.5,
      "recall" => 1.0
    )
    expect(summary["fields"]["ink.kinds_include"]).to include("precision" => 1.0, "recall" => 1.0)
    expect(summary["by_split"].keys).to eq(%w[dev test])
    expect(summary["by_split"]["dev"]).to include("scored" => 1, "hard_false_positive_rate" => 0.0)
    expect(summary["reviewed"]).to include("strings" => 0, "hard_false_positive_rate" => nil)
  end

  it "counts the strings whose labelled names the extractor did not mention" do
    labels = [
      label(
        "Lamy 2000 with Kon-peki",
        { "pen" => { "mentions" => ["Lamy 2000"] }, "ink" => { "mentions" => ["Kon-peki"] } }
      ),
      label("ink for the Halcyon Slim", { "pen" => { "mentions" => ["Corvid Halcyon Slim"] } }),
      label("use Kestrel Blue", { "ink" => { "mentions" => ["Kestrel Blue"] } }),
      label("something red", { "ink" => { "colour_include" => ["red"] } })
    ]
    predictions = {
      "Lamy 2000 with Kon-peki" => prediction({ "pen" => { "mentions" => ["Lamy 2000"] } }),
      "ink for the Halcyon Slim" => prediction({ "pen" => { "mentions" => ["Halcyon Slim"] } }),
      "use Kestrel Blue" => prediction({ "pen" => { "mentions" => ["Kestrel Blue"] } }),
      "something red" => prediction({ "ink" => { "colour_include" => ["red"] } })
    }

    scored = score(labels, predictions)

    expect(scored.rows.map { |row| row["missed_named_mentions"] }).to eq([["Kon-peki"], [], [], []])
    expect(scored.summary).to include(
      "with_named_mention" => 3,
      "with_missed_named_mention" => 1,
      "missed_named_mention_rate" => 0.3333
    )
  end

  it "skips labels without a prediction" do
    expect(score([label("only samples")], {}).rows).to be_empty
  end
end
