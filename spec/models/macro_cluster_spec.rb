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
  end
end
