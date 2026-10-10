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
end
