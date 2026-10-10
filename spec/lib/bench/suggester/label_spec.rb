require_relative "bench_helper"

RSpec.describe Bench::Suggester::Label do
  let(:valid) do
    {
      "categories" => %w[specific_pen nib],
      "named_pens" => [12],
      "named_inks" => [],
      "constraints" => {
        "pen" => {
          "nib_grades_include" => %w[m b],
          "exclude_mentions" => ["Parker"]
        },
        "ink" => {
          "kinds_include" => ["Sample"],
          "colour_exclude" => ["blue"],
          "shimmer" => "exclude"
        },
        "pair_usage" => "new"
      },
      "reviewed" => false,
      "notes" => "Pen named by model"
    }
  end

  it "normalises enum values" do
    label = described_class.from_h(45, valid)

    expect(label.case_id).to eq("45")
    expect(label.constraints).to eq(
      {
        "pair_usage" => "new",
        "pen" => {
          "nib_grades_include" => %w[M B],
          "exclude_mentions" => ["Parker"]
        },
        "ink" => {
          "kinds_include" => ["sample"],
          "colour_exclude" => ["blue"],
          "shimmer" => "exclude"
        }
      }
    )
    expect(label).not_to be_reviewed
    expect(label).not_to be_corrected
    expect(label.to_h).to include("named_pens" => [12], "categories" => %w[specific_pen nib])
  end

  it "accepts an empty label" do
    label = described_class.from_h(1, nil)

    expect(label).to have_attributes(
      categories: [],
      named_pens: [],
      named_inks: [],
      constraints: {
      }
    )
  end

  it "accepts every field of the extractor schema" do
    constraints = {
      "out_of_scope" => true,
      "requested_count" => 5,
      "keep_from_previous" => "pen",
      "soft_notes" => "autumn",
      "pen" => {
        "mentions" => ["M800"],
        "comment_exclude" => ["Anna"],
        "nib_width" => "broadish",
        "nib_characters_exclude" => ["stub"],
        "usage" => "never_used",
        "sort" => "most_used"
      },
      "ink" => {
        "mentions" => ["Kon-peki"],
        "tags_exclude" => ["ordered"],
        "colour_include" => ["teal"],
        "scented" => "include",
        "usage" => "used_before",
        "exclude_ids" => [3]
      }
    }

    expect(described_class.from_h(1, "constraints" => constraints).constraints).to eq(constraints)
  end

  {
    "an unknown key" => {
      "named" => [1]
    },
    "an unknown category" => {
      "categories" => ["vibes"]
    },
    "a non-integer target" => {
      "named_pens" => ["12"]
    },
    "an unknown constraint" => {
      "constraints" => {
        "pen" => {
          "colour_include" => ["blue"]
        }
      }
    },
    "an unknown side" => {
      "constraints" => {
        "paper" => {
        }
      }
    },
    "an unknown enum value" => {
      "constraints" => {
        "pen" => {
          "nib_width" => "wide"
        }
      }
    },
    "an unknown list value" => {
      "constraints" => {
        "ink" => {
          "kinds_include" => ["swab"]
        }
      }
    },
    "a scalar for a list" => {
      "constraints" => {
        "ink" => {
          "colour_exclude" => "blue"
        }
      }
    },
    "a string id" => {
      "constraints" => {
        "pen" => {
          "exclude_ids" => ["4"]
        }
      }
    },
    "a correction without a review" => {
      "corrected" => true
    },
    "a zero count" => {
      "constraints" => {
        "requested_count" => 0
      }
    }
  }.each do |description, hash|
    it "rejects #{description}" do
      expect { described_class.from_h(7, hash) }.to raise_error(
        Bench::Suggester::ConstraintSchema::Invalid,
        /label 7/
      )
    end
  end

  it "records whether the owner's review changed the drafted label" do
    confirmed = described_class.from_h(1, "reviewed" => true)
    corrected = described_class.from_h(2, "reviewed" => true, "corrected" => true)

    expect(confirmed).to be_reviewed
    expect(confirmed).not_to be_corrected
    expect(corrected).to be_corrected
    expect(corrected.to_h).to include("reviewed" => true, "corrected" => true)
  end

  it "loads a YAML file keyed by case id" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "labels.yml")
      File.write(path, { 45 => valid, "46" => {} }.to_yaml)

      labels = described_class.load_file(path)

      expect(labels.keys).to eq(%w[45 46])
      expect(labels["45"].named_pens).to eq([12])
      expect(described_class.load_file(File.join(dir, "missing.yml"))).to eq({})
    end
  end
end

RSpec.describe Bench::Suggester::ExtractorLabel do
  it "loads labelled instruction strings" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "extractor_labels.yml")
      File.write(
        path,
        [
          {
            "text" => "Only samples, use them up",
            "constraints" => {
              "ink" => {
                "kinds_include" => ["sample"]
              }
            }
          }
        ].to_yaml
      )

      label = described_class.load_file(path).sole

      expect(label.text).to eq("Only samples, use them up")
      expect(label.constraints).to eq({ "ink" => { "kinds_include" => ["sample"] } })
    end
  end

  it "rejects bench-only ids, blank texts and duplicate texts" do
    expect {
      described_class.from_h(
        { "text" => "x", "constraints" => { "pen" => { "exclude_ids" => [1] } } }
      )
    }.to raise_error(Bench::Suggester::ConstraintSchema::Invalid, /bench-only/)
    expect { described_class.from_h({ "text" => " " }) }.to raise_error(
      Bench::Suggester::ConstraintSchema::Invalid,
      /blank/
    )
    Dir.mktmpdir do |dir|
      path = File.join(dir, "extractor_labels.yml")
      File.write(path, [{ "text" => "Not a Parker" }, { "text" => "not a  parker" }].to_yaml)

      expect { described_class.load_file(path) }.to raise_error(
        Bench::Suggester::ConstraintSchema::Invalid,
        /more than once/
      )
    end
  end
end
