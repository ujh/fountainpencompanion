require_relative "bench_helper"

RSpec.describe Bench::Suggester::LabellingSheet do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let!(:pen) do
    create(
      :collected_pen,
      user:,
      created_at: as_of - 1.year,
      brand: "Lamy",
      model: "2000",
      nib: "B",
      color: "black",
      material: "makrolon",
      trim_color: "",
      filling_system: "piston",
      comment: "Needs a wet ink"
    )
  end
  let!(:ink) do
    create(
      :collected_ink,
      user:,
      created_at: as_of - 1.year,
      brand_name: "Sailor",
      line_name: "Shikiori",
      ink_name: "Yozakura",
      kind: "sample",
      color: "#A0A0C0",
      tags_as_string: "shimmer, spring",
      comment: "Sheens red",
      micro_cluster:
        create(
          :micro_cluster,
          macro_cluster: create(:macro_cluster, tags: ["purple"], description: "Lovely")
        )
    )
  end

  def bench_case(id: "7", instruction: "Ink for my Lamy 2000", rejected_pairs: [])
    Bench::Suggester::BenchCase.new(
      id:,
      log_id: id.to_i,
      user_id: user.id,
      as_of:,
      source: instruction ? "instruction" : "plain",
      split: "dev",
      tier: "free",
      instruction:,
      rejected_pairs:,
      original: {
        "pen_id" => pen.id,
        "ink_id" => ink.id,
        "message" => "Historical answer"
      },
      fidelity: {
        "pens" => 1.0
      }
    )
  end

  def document(**options)
    described_class.new(cases: [bench_case(**options)]).documents.sole
  end

  it "holds the request and the collection at as_of, but not the logged outcome" do
    create(:collected_pen, user:, created_at: as_of + 1.day)
    create(:collected_ink, user:, created_at: as_of - 1.year, archived_on: as_of.to_date - 1)

    sheet_document = document

    expect(sheet_document.except("pens", "inks", "rejected_pairs")).to eq(
      "case_id" => "7",
      "source" => "instruction",
      "split" => "dev",
      "tier" => "free",
      "as_of" => "2026-05-01",
      "instruction" => "Ink for my Lamy 2000"
    )
    expect(sheet_document["pens"].map { |row| row["id"] }).to eq([pen.id])
    expect(sheet_document["inks"].map { |row| row["id"] }).to eq([ink.id])
    expect(sheet_document.to_json).not_to include("Historical answer", "fidelity", "user_id")
  end

  it "lists each pen with its nib and each ink with kind, colour and tags" do
    sheet_document = document

    expect(sheet_document["pens"].sole).to eq(
      "id" => pen.id,
      "brand" => "Lamy",
      "model" => "2000",
      "nib" => "B",
      "color" => "black",
      "material" => "makrolon",
      "filling_system" => "piston",
      "comment" => "Needs a wet ink",
      "inked" => false,
      "usage_count" => 0
    )
    expect(sheet_document["inks"].sole).to eq(
      "id" => ink.id,
      "brand" => "Sailor",
      "line" => "Shikiori",
      "name" => "Yozakura",
      "kind" => "sample",
      "color" => "#A0A0C0",
      "tags" => %w[shimmer spring],
      "cluster_tags" => ["purple"],
      "comment" => "Sheens red",
      "inked" => false,
      "usage_count" => 0
    )
  end

  it "marks items inked at as_of and gives their usage" do
    create(
      :currently_inked,
      user:,
      collected_pen: pen,
      collected_ink: ink,
      inked_on: as_of.to_date - 10,
      created_at: as_of - 10.days
    )

    sheet_document = document

    expect(sheet_document["pens"].sole).to include(
      "inked" => true,
      "usage_count" => 1,
      "last_activity_on" => "2026-05-01"
    )
    expect(sheet_document["inks"].sole).to include("inked" => true, "usage_count" => 1)
  end

  it "names the rejected pairs" do
    sheet_document = document(rejected_pairs: [{ "pen_id" => pen.id, "ink_id" => 0 }])

    expect(sheet_document["rejected_pairs"]).to eq(
      [
        {
          "pen_id" => pen.id,
          "pen" => "Lamy 2000 black makrolon piston",
          "ink_id" => 0,
          "ink" => nil
        }
      ]
    )
  end

  it "skips cases whose user is gone" do
    gone = bench_case(id: "8").with(user_id: 0)

    expect(described_class.new(cases: [bench_case, gone]).documents.map { _1["case_id"] }).to eq(
      ["7"]
    )
  end

  describe "#files" do
    subject(:files) do
      described_class.new(cases: [bench_case, bench_case(id: "9", instruction: nil)]).files
    end

    it "writes one JSON file per case with one item per line" do
      text = files.fetch("cases/7.json")

      expect(JSON.parse(text)).to eq(document)
      expect(text.lines.grep(/"id":#{pen.id},/).size).to eq(1)
      expect(text.lines.grep(/"id":#{ink.id},/).size).to eq(1)
    end

    it "indexes the cases without their outcomes" do
      expect(JSON.parse(files.fetch("index.json"))).to eq(
        [
          {
            "case_id" => "7",
            "source" => "instruction",
            "split" => "dev",
            "instruction" => true,
            "pens" => 1,
            "inks" => 1
          },
          {
            "case_id" => "9",
            "source" => "plain",
            "split" => "dev",
            "instruction" => false,
            "pens" => 1,
            "inks" => 1
          }
        ]
      )
    end

    it "documents a label format whose example the label schema accepts" do
      readme = files.fetch("README.md")
      example = YAML.safe_load(readme[/```yaml\n(.*?)```/m, 1])

      expect(example.keys).to eq(["1001"])
      expect { Bench::Suggester::Label.from_h("1001", example["1001"]) }.not_to raise_error
      expect(readme).to include(
        *Bench::Suggester::Label::CATEGORIES,
        *Bench::Suggester::ConstraintSchema::INK_FIELDS.keys.map { "`#{_1}`" },
        ColorProfile::FAMILIES.join(", ")
      )
    end
  end
end
