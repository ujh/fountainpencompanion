require_relative "bench_helper"

RSpec.describe Bench::Suggester::LabelValidator do
  let(:dir) { Dir.mktmpdir }
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let!(:pen) { create(:collected_pen, user:, created_at: as_of - 1.year) }
  let!(:ink) { create(:collected_ink, user:, created_at: as_of - 1.year) }
  let(:path) { File.join(dir, "labels.yml") }

  after { FileUtils.remove_entry(dir) }

  def bench_case(id, instruction: "Ink for my pen", user_id: user.id)
    Bench::Suggester::BenchCase.new(
      id:,
      log_id: id.to_i,
      user_id:,
      as_of:,
      source: instruction ? "instruction" : "plain",
      split: "dev",
      tier: "free",
      instruction:,
      rejected_pairs: [],
      original: {
      },
      fidelity: {
      }
    )
  end

  let(:cases) { [bench_case("1"), bench_case("2", instruction: nil)] }

  def label(**overrides)
    {
      "categories" => ["specific_pen"],
      "named_pens" => [pen.id],
      "named_inks" => [],
      "constraints" => {
        "ink" => {
          "kinds_include" => ["sample"]
        }
      },
      "reviewed" => false,
      "corrected" => false,
      "notes" => "Use the named pen."
    }.merge(overrides.stringify_keys)
  end

  def errors_for(labels)
    File.write(path, labels.to_yaml)
    described_class.new(cases:).errors(path)
  end

  it "accepts drafted labels for exported cases" do
    expect(
      errors_for("1" => label, "2" => label(categories: [], named_pens: [], constraints: {}))
    ).to eq([])
  end

  it "rejects schema errors" do
    expect(
      errors_for("1" => label(constraints: { "ink" => { "kinds_include" => ["vial"] } }))
    ).to eq(["#{path}: label 1.constraints.ink.kinds_include: invalid value [\"vial\"]"])
  end

  it "rejects labels for unknown cases and labels marked as reviewed" do
    expect(errors_for("3" => label, "1" => label(reviewed: true))).to eq(
      ["label 3: no such case", "label 1: reviewed is set by the owner only"]
    )
  end

  it "rejects categories or constraints on a case without an instruction" do
    expect(errors_for("2" => label(named_pens: []))).to eq(["label 2: the case has no instruction"])
  end

  it "rejects ids outside the collection at as_of" do
    later_pen = create(:collected_pen, user:, created_at: as_of + 1.day)

    expect(errors_for("1" => label(named_pens: [pen.id, later_pen.id]))).to eq(
      ["label 1: named_pens not in the collection at as_of: #{later_pen.id}"]
    )
  end

  it "reports a case whose user is gone" do
    cases << bench_case("4", user_id: 0)

    expect(errors_for("4" => label)).to eq(["label 4: the case's user is gone"])
  end

  it "reports a missing file, a non-mapping and broken YAML" do
    validator = described_class.new(cases:)
    expect(validator.errors(File.join(dir, "none.yml"))).to eq(["#{dir}/none.yml: no such file"])

    File.write(path, ["1"].to_yaml)
    expect(validator.errors(path)).to eq(["#{path}: must be a mapping keyed by case id"])

    File.write(path, "1: [unclosed")
    expect(validator.errors(path).sole).to start_with("#{path}: ")
  end
end
