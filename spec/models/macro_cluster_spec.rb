require "rails_helper"

describe MacroCluster do
  describe "#without_review" do
    let!(:macro_cluster) { create(:macro_cluster) }

    subject { described_class.without_review }

    it "returns clusters without any ink reviews" do
      expect(subject).to eq([macro_cluster])
    end

    it "does not return a cluster with a new ink review" do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: nil)
      expect(subject).to be_empty
    end

    it "does not return a cluster with an approved ink review" do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: Time.now, rejected_at: nil)
      expect(subject).to be_empty
    end

    it "returns a cluster with a rejected review" do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: Time.now)
      expect(subject).to eq([macro_cluster])
    end

    it "returns a cluster with multiple rejected reviews" do
      create_list(
        :ink_review,
        2,
        macro_cluster: macro_cluster,
        approved_at: nil,
        rejected_at: Time.now
      )
      expect(subject.count).to eq(1)
      expect(subject).to eq([macro_cluster])
    end

    it "does not return a cluster with an approved and a reject review" do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: Time.now, rejected_at: nil)
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: Time.now)
      expect(subject).to be_empty
    end

    it "does not return a cluster with a new and a rejected review" do
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: nil)
      create(:ink_review, macro_cluster: macro_cluster, approved_at: nil, rejected_at: Time.now)
      expect(subject).to be_empty
    end
  end

  describe "#brand_name" do
    it "returns the database brand_name when manual_brand_name is nil" do
      cluster = create(:macro_cluster, brand_name: "Pilot", manual_brand_name: nil)
      expect(cluster.brand_name).to eq("Pilot")
    end

    it "returns the database brand_name when manual_brand_name is blank" do
      cluster = create(:macro_cluster, brand_name: "Pilot", manual_brand_name: "")
      expect(cluster.brand_name).to eq("Pilot")
    end

    it "returns manual_brand_name when present" do
      cluster = create(:macro_cluster, brand_name: "Pilot", manual_brand_name: "PILOT")
      expect(cluster.brand_name).to eq("PILOT")
    end
  end

  describe "#line_name" do
    it "returns the database line_name when manual_line_name is nil" do
      cluster = create(:macro_cluster, line_name: "Iroshizuku", manual_line_name: nil)
      expect(cluster.line_name).to eq("Iroshizuku")
    end

    it "returns the database line_name when manual_line_name is blank" do
      cluster = create(:macro_cluster, line_name: "Iroshizuku", manual_line_name: "")
      expect(cluster.line_name).to eq("Iroshizuku")
    end

    it "returns manual_line_name when present" do
      cluster = create(:macro_cluster, line_name: "Iroshizuku", manual_line_name: "iroshizuku")
      expect(cluster.line_name).to eq("iroshizuku")
    end

    it "returns empty string when line_name_is_empty is true" do
      cluster = create(:macro_cluster, line_name: "Iroshizuku", line_name_is_empty: true)
      expect(cluster.line_name).to eq("")
    end

    it "returns empty string when line_name_is_empty is true even with manual override" do
      cluster =
        create(
          :macro_cluster,
          line_name: "Iroshizuku",
          manual_line_name: "iroshizuku",
          line_name_is_empty: true
        )
      expect(cluster.line_name).to eq("")
    end
  end

  describe "#ink_name" do
    it "returns the database ink_name when manual_ink_name is nil" do
      cluster = create(:macro_cluster, ink_name: "Kon-peki", manual_ink_name: nil)
      expect(cluster.ink_name).to eq("Kon-peki")
    end

    it "returns the database ink_name when manual_ink_name is blank" do
      cluster = create(:macro_cluster, ink_name: "Kon-peki", manual_ink_name: "")
      expect(cluster.ink_name).to eq("Kon-peki")
    end

    it "returns manual_ink_name when present" do
      cluster = create(:macro_cluster, ink_name: "Kon-peki", manual_ink_name: "Kon-Peki")
      expect(cluster.ink_name).to eq("Kon-Peki")
    end
  end

  describe "#automatic_brand_name" do
    it "returns the database brand_name even when manual override is set" do
      cluster = create(:macro_cluster, brand_name: "Pilot", manual_brand_name: "PILOT")
      expect(cluster.automatic_brand_name).to eq("Pilot")
    end
  end

  describe "#automatic_line_name" do
    it "returns the database line_name even when manual override is set" do
      cluster = create(:macro_cluster, line_name: "Iroshizuku", manual_line_name: "iroshizuku")
      expect(cluster.automatic_line_name).to eq("Iroshizuku")
    end
  end

  describe "#automatic_ink_name" do
    it "returns the database ink_name even when manual override is set" do
      cluster = create(:macro_cluster, ink_name: "Kon-peki", manual_ink_name: "Kon-Peki")
      expect(cluster.automatic_ink_name).to eq("Kon-peki")
    end
  end

  describe "#name" do
    it "composes name from brand, line, and ink" do
      cluster =
        create(:macro_cluster, brand_name: "Pilot", line_name: "Iroshizuku", ink_name: "Kon-peki")
      expect(cluster.name).to eq("Pilot Iroshizuku Kon-peki")
    end

    it "uses manual overrides in the composed name" do
      cluster =
        create(
          :macro_cluster,
          brand_name: "pilot",
          line_name: "iroshizuku",
          ink_name: "kon-peki",
          manual_brand_name: "Pilot",
          manual_line_name: "Iroshizuku",
          manual_ink_name: "Kon-Peki"
        )
      expect(cluster.name).to eq("Pilot Iroshizuku Kon-Peki")
    end

    it "skips blank parts" do
      cluster = create(:macro_cluster, brand_name: "Pilot", line_name: "", ink_name: "Kon-peki")
      expect(cluster.name).to eq("Pilot Kon-peki")
    end

    it "skips line_name when line_name_is_empty is true" do
      cluster =
        create(
          :macro_cluster,
          brand_name: "Pilot",
          line_name: "Iroshizuku",
          ink_name: "Kon-peki",
          line_name_is_empty: true
        )
      expect(cluster.name).to eq("Pilot Kon-peki")
    end
  end

  describe "#recalculate_color" do
    let(:macro_cluster) { create(:macro_cluster, color: "#FFFFFF") }
    let(:micro_cluster) { create(:micro_cluster, macro_cluster: macro_cluster) }

    it "recalculates color when ignored_colors changes" do
      create(:collected_ink, micro_cluster: micro_cluster, color: "#111111")
      create(:collected_ink, micro_cluster: micro_cluster, color: "#333333")
      macro_cluster.update!(ignored_colors: ["#111111"])
      expect(macro_cluster.reload.color).to eq("#333333")
    end

    it "excludes ignored colors from the average" do
      create(:collected_ink, micro_cluster: micro_cluster, color: "#111111")
      create(:collected_ink, micro_cluster: micro_cluster, color: "#333333")
      create(:collected_ink, micro_cluster: micro_cluster, color: "#555555")
      macro_cluster.update!(ignored_colors: ["#111111"])
      # RMS of #333333 and #555555
      macro_cluster.reload
      expect(macro_cluster.color).to eq("#464646")
    end

    it "does not change color when all colors are ignored" do
      create(:collected_ink, micro_cluster: micro_cluster, color: "#111111")
      macro_cluster.update!(ignored_colors: ["#111111"])
      expect(macro_cluster.reload.color).to eq("#FFFFFF")
    end

    it "enqueues UpdateMacroCluster when color changes" do
      create(:collected_ink, micro_cluster: micro_cluster, color: "#111111")
      create(:collected_ink, micro_cluster: micro_cluster, color: "#333333")
      expect { macro_cluster.update!(ignored_colors: ["#111111"]) }.to change {
        UpdateMacroCluster.jobs.size
      }.by(1)
    end
  end

  describe "#manual_edits?" do
    it "returns false when no manual fields are set" do
      cluster =
        create(
          :macro_cluster,
          description: "",
          manual_brand_name: nil,
          manual_line_name: nil,
          manual_ink_name: nil
        )
      expect(cluster.manual_edits?).to be false
    end

    it "returns true when description is present" do
      cluster = create(:macro_cluster, description: "A nice ink")
      expect(cluster.manual_edits?).to be true
    end

    it "returns true when manual_brand_name is present" do
      cluster = create(:macro_cluster, manual_brand_name: "Pilot")
      expect(cluster.manual_edits?).to be true
    end

    it "returns true when manual_line_name is present" do
      cluster = create(:macro_cluster, manual_line_name: "Iroshizuku")
      expect(cluster.manual_edits?).to be true
    end

    it "returns true when manual_ink_name is present" do
      cluster = create(:macro_cluster, manual_ink_name: "Kon-Peki")
      expect(cluster.manual_edits?).to be true
    end

    it "returns true when line_name_is_empty is true" do
      cluster = create(:macro_cluster, line_name_is_empty: true)
      expect(cluster.manual_edits?).to be true
    end
  end

  describe ".embedding_search" do
    it "returns an empty array for a blank query without calling the embeddings client" do
      expect(EmbeddingsClient).not_to receive(:new)

      expect(described_class.embedding_search(nil)).to eq([])
      expect(described_class.embedding_search("")).to eq([])
    end
  end

  describe ".autocomplete_search" do
    def add_inks(count, brand_name: "Diamine", ink_name: "Blue", private: false, macro_cluster: nil)
      macro_cluster ||= create(:macro_cluster, brand_name: brand_name, ink_name: ink_name)
      micro_cluster =
        create(
          :micro_cluster,
          macro_cluster: macro_cluster,
          simplified_brand_name: Simplifier.brand_name(brand_name)
        )
      create_list(
        :collected_ink,
        count,
        brand_name: brand_name,
        ink_name: ink_name,
        micro_cluster: micro_cluster,
        private: private
      )
      macro_cluster
    end

    def search(term, brand_name = nil)
      MacroClusterPopularity.refresh
      described_class.autocomplete_search(term, :ink_name, brand_name).map { |c| c[:name] }
    end

    it "ranks names by match quality and then by number of public inks" do
      add_inks(3, ink_name: "Royal Blue")
      add_inks(5, ink_name: "Blue Velvet")
      add_inks(3, ink_name: "Blue Black")

      expect(search("blue")).to eq(["Blue Velvet", "Blue Black", "Royal Blue"])
    end

    it "only includes names with more than two public inks" do
      add_inks(3, ink_name: "Blue Velvet")
      add_inks(2, ink_name: "Blue Black")
      add_inks(5, ink_name: "Bluebell", private: true)

      expect(search("blue")).to eq(["Blue Velvet"])
    end

    it "merges names that only differ in case, using the most popular spelling" do
      add_inks(4, brand_name: "Diamine", ink_name: "Oxblood")
      add_inks(2, brand_name: "Pilot", ink_name: "oxblood")

      expect(search("oxb")).to eq(["Oxblood"])
    end

    it "counts the merged names together for the threshold" do
      add_inks(2, brand_name: "Diamine", ink_name: "Oxblood")
      add_inks(1, brand_name: "Pilot", ink_name: "oxblood")

      expect(search("oxb")).to eq(["Oxblood"])
    end

    it "uses the manual name if present" do
      cluster = create(:macro_cluster, ink_name: "Oxblod", manual_ink_name: "Oxblood")
      add_inks(3, ink_name: "Oxblod", macro_cluster: cluster)

      expect(search("oxb")).to eq(["Oxblood"])
    end

    it "only includes inks of the given brand" do
      add_inks(3, brand_name: "Diamine", ink_name: "Blue Velvet")
      add_inks(3, brand_name: "Pilot Namiki", ink_name: "Blue Black")
      add_inks(3, brand_name: "Pilot", ink_name: "Blue")

      expect(search("blue", "pilot")).to eq(["Blue"])
    end

    it "finds names with typos" do
      add_inks(3, ink_name: "Oxblood")

      expect(search("oxbld")).to eq(["Oxblood"])
    end
  end

  describe ".autocomplete_ink_search" do
    it "returns one macro cluster per name in ranking order" do
      velvet = create(:macro_cluster, ink_name: "Blue Velvet")
      royal = create(:macro_cluster, ink_name: "Royal Blue")
      [[velvet, 3], [royal, 5]].each do |cluster, count|
        micro_cluster = create(:micro_cluster, macro_cluster: cluster)
        create_list(:collected_ink, count, ink_name: cluster.ink_name, micro_cluster: micro_cluster)
      end

      MacroClusterPopularity.refresh

      expect(described_class.autocomplete_ink_search("blue", "")).to eq([velvet, royal])
    end
  end
end
