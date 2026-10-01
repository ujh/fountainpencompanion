require "rails_helper"

describe AutocompleteRanking do
  # Builds a candidates relation from [name, popularity] pairs
  def candidates(*rows)
    values =
      rows.map { |name, popularity| BrandCluster.sanitize_sql_array(["(?, ?)", name, popularity]) }
    BrandCluster
      .unscoped
      .from("(VALUES #{values.join(", ")}) AS candidates(name, popularity)")
      .select("candidates.*")
  end

  def rank(term, *rows, **options)
    described_class.new(candidates(*rows), term, **options).names
  end

  it "ranks exact matches, then prefixes, word starts, substrings and similar names" do
    names =
      rank(
        "pel",
        ["Diamine Pelikan Blue", 100],
        ["Spelling Bee", 100],
        ["Pelikan", 1],
        ["Pel", 1],
        ["Pell", 1]
      )

    expect(names).to eq(["Pel", "Pelikan", "Pell", "Diamine Pelikan Blue", "Spelling Bee"])
  end

  it "orders by popularity within a tier and alphabetically after that" do
    names = rank("pe", ["Pent", 1], ["Pelikan", 50], ["Pebeo", 1], ["PenBBS", 10])

    expect(names).to eq(%w[Pelikan PenBBS Pebeo Pent])
  end

  it "matches case-insensitively" do
    expect(rank("PILOT", ["pilot", 1], ["Pilot Iroshizuku", 1])).to eq(
      ["pilot", "Pilot Iroshizuku"]
    )
  end

  it "ignores leading and trailing whitespace in the term" do
    expect(rank("  pilot ", ["Pilot", 1])).to eq(["Pilot"])
  end

  it "matches word starts after punctuation" do
    expect(rank("peki", ["Kon-Peki", 1], ["Pekingese", 1])).to eq(%w[Pekingese Kon-Peki])
  end

  it "matches names when ignoring punctuation and spaces" do
    expect(rank("konpeki", ["Kon-Peki", 1])).to eq(["Kon-Peki"])
    expect(rank("kon peki", ["Kon-Peki", 1])).to eq(["Kon-Peki"])
  end

  it "matches similar names to catch typos" do
    expect(rank("pelican", ["Pelikan", 1], ["Diamine", 1])).to eq(["Pelikan"])
  end

  it "prefers popular similar names over slightly closer rare ones" do
    names = rank("pelican", ["Pelica Pens", 1], ["Pelikan Ink", 1000])

    expect(names).to eq(["Pelikan Ink", "Pelica Pens"])
  end

  it "matches compact names without punctuation in the term" do
    expect(rank("custom74", ["Custom 74", 1])).to eq(["Custom 74"])
  end

  it "matches similar names with a typo at the start or the end" do
    expect(rank("pelikam", ["Pelikan", 1])).to eq(["Pelikan"])
    expect(rank("belikan", ["Pelikan", 1])).to eq(["Pelikan"])
  end

  it "does not match similar names when both the first and last two characters are wrong" do
    expect(rank("ablueberryzz", ["Blueberry", 1])).to eq([])
  end

  it "does not match similar names for short terms" do
    expect(rank("pio", ["Pilot", 1])).to eq([])
  end

  it "excludes names that don't match" do
    expect(rank("diamine", ["Pilot", 1], ["Sailor", 1])).to eq([])
  end

  it "treats LIKE wildcards in the term literally" do
    expect(rank("a%c", ["a%c", 1], ["abc", 1])).to eq(["a%c"])
    expect(rank("a_b", ["a_b", 1], ["axb", 1])).to eq(["a_b"])
  end

  it "handles question marks in the term" do
    expect(rank("what?", ["What? Blue", 1])).to eq(["What? Blue"])
  end

  it "limits the number of results" do
    rows = (1..20).map { |i| ["Pen #{i}", i] }

    expect(rank("pen", *rows).length).to eq(described_class::LIMIT)
    expect(rank("pen", *rows, limit: 3)).to eq(["Pen 20", "Pen 19", "Pen 18"])
  end

  it "returns the full candidate records" do
    relation = described_class.new(candidates(["Pilot", 7]), "pil").relation

    expect(relation.first[:popularity]).to eq(7)
  end
end
