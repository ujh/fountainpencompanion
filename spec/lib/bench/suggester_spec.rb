require_relative "suggester/bench_helper"

RSpec.describe Bench::Suggester do
  describe ".parse_since" do
    let(:default) { Time.utc(2026, 3, 24) }

    it "parses a date in the app time zone" do
      expect(described_class.parse_since("2025-11-01", default:)).to eq(
        Time.zone.local(2025, 11, 1)
      )
    end

    it "returns the default when the value is missing" do
      expect(described_class.parse_since(nil, default:)).to eq(default)
    end

    it "returns the default when the value is blank" do
      expect(described_class.parse_since("  ", default:)).to eq(default)
    end

    it "raises on a value that is not a date" do
      expect { described_class.parse_since("notadate", default:) }.to raise_error(
        ArgumentError,
        /notadate/
      )
    end
  end

  describe ".filter_cases" do
    def bench_case(id, split:, instruction:)
      Bench::Suggester::BenchCase.new(
        id:,
        log_id: 1,
        user_id: 1,
        as_of: Time.current,
        source: instruction ? "instruction" : "plain",
        split:,
        tier: "free",
        instruction:,
        rejected_pairs: [],
        original: {
        },
        fidelity: {
        }
      )
    end

    let(:cases) do
      [
        bench_case("1", split: "dev", instruction: "blue"),
        bench_case("2", split: "test", instruction: nil),
        bench_case("3", split: "test", instruction: "red")
      ]
    end

    def ids(**filters) = described_class.filter_cases(cases, **filters).map(&:id)

    it "keeps every case without filters" do
      expect(ids).to eq(%w[1 2 3])
      expect(ids(split: "", instruction: "")).to eq(%w[1 2 3])
    end

    it "filters by split and by whether the case has an instruction" do
      expect(ids(split: "test")).to eq(%w[2 3])
      expect(ids(instruction: "without")).to eq(%w[2])
      expect(ids(instruction: "with", split: "test")).to eq(%w[3])
    end

    it "rejects an unknown instruction filter" do
      expect { ids(instruction: "none") }.to raise_error(ArgumentError, /none/)
    end
  end
end
