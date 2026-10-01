require "rails_helper"

describe PenNamePopularity do
  def rows(field)
    described_class
      .where(field: field)
      .order(:brand_key, :value_key)
      .pluck(:brand_key, :value_key, :value, :popularity)
  end

  describe ".refresh" do
    it "counts the users per brand" do
      user = create(:user)
      create_list(:collected_pen, 2, user: user, brand: "Pilot")
      create(:collected_pen, brand: "Pilot")
      create(:collected_pen, brand: "Sailor")

      described_class.refresh

      expect(rows("brand")).to eq([%w[pilot pilot Pilot] + [2], %w[sailor sailor Sailor] + [1]])
    end

    it "counts the users per model of a brand" do
      create(:collected_pen, brand: "Pilot", model: "Custom 74")
      create(:collected_pen, brand: "Pilot", model: "Custom 74")
      create(:collected_pen, brand: "Namiki", model: "Custom 74")

      described_class.refresh

      expect(rows("model")).to eq(
        [["namiki", "custom 74", "Custom 74", 1], ["pilot", "custom 74", "Custom 74", 2]]
      )
    end

    it "merges values that only differ in case or surrounding spaces" do
      create_list(:collected_pen, 2, brand: "Pilot")
      create(:collected_pen, brand: "pilot")
      create(:collected_pen).update_column(:brand, " Pilot ")

      described_class.refresh

      expect(rows("brand")).to eq([%w[pilot pilot Pilot] + [4]])
    end

    it "ignores empty values" do
      create(:collected_pen, brand: "Pilot").update_column(:model, " ")

      described_class.refresh

      expect(rows("model")).to eq([])
    end

    it "picks up new pens" do
      described_class.refresh
      create(:collected_pen, brand: "Pilot")

      expect { described_class.refresh }.to change { rows("brand").length }.from(0).to(1)
    end

    it "is read-only" do
      create(:collected_pen)
      described_class.refresh

      expect(described_class.take).to be_readonly
    end
  end
end
