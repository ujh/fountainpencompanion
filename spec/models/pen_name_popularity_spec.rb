require "rails_helper"

describe PenNamePopularity do
  def rows(field)
    described_class
      .where(field: field)
      .order(:brand_key, :value_key)
      .pluck(:brand_key, :value_key, :value, :popularity)
  end

  def add_pens(count, **attributes)
    count.times { create(:collected_pen, **attributes) }
  end

  def search(field, term, user: create(:user), **options)
    described_class.refresh
    described_class.autocomplete_search(term, field, user: user, **options)
  end

  describe ".autocomplete_search" do
    it "ranks brands by match quality and then by number of users" do
      add_pens(2, brand: "Platinum")
      add_pens(3, brand: "Pilot")
      add_pens(4, brand: "Kaweco Sport")
      add_pens(4, brand: "Pelikan")

      expect(search(:brand, "p")).to eq(["Pelikan", "Pilot", "Platinum", "Kaweco Sport"])
    end

    it "counts users instead of pens" do
      user = create(:user)
      3.times { create(:collected_pen, user: user, brand: "Platinum") }
      add_pens(1, brand: "Platinum")
      add_pens(3, brand: "Pilot")

      expect(search(:brand, "p")).to eq(%w[Pilot Platinum])
    end

    it "merges values that only differ in case or surrounding spaces" do
      add_pens(2, brand: "Pilot")
      add_pens(1, brand: "pilot")
      create(:collected_pen).update_column(:brand, " Pilot ")

      expect(search(:brand, "pil")).to eq(["Pilot"])
    end

    it "finds values with typos" do
      add_pens(2, brand: "Pelikan")

      expect(search(:brand, "pelican")).to eq(["Pelikan"])
    end

    it "does not suggest values of a single other user" do
      add_pens(1, brand: "Rare Pens", model: "Rare Model")

      expect(search(:brand, "rare")).to eq([])
      expect(search(:model, "rare")).to eq([])
      expect(search(:model, "rare", brand: "Rare Pens")).to eq([])
    end

    it "suggests the user's own values" do
      user = create(:user)
      create(:collected_pen, user: user, brand: "Rare Pens", model: "Rare Model")

      expect(search(:brand, "rare", user: user)).to eq(["Rare Pens"])
      expect(search(:model, "rare", user: user)).to eq(["Rare Model"])
      expect(search(:model, "rare", user: user, brand: " rare pens ")).to eq(["Rare Model"])
    end

    it "suggests the user's own archived values" do
      user = create(:user)
      create(:collected_pen, user: user, brand: "Rare Pens", archived_on: Date.current)

      expect(search(:brand, "rare", user: user)).to eq(["Rare Pens"])
    end

    it "shows the user's own value once with the more common spelling" do
      user = create(:user)
      create(:collected_pen, user: user, brand: "pilot ")
      add_pens(2, brand: "Pilot")

      expect(search(:brand, "pil", user: user)).to eq(["Pilot"])
    end

    it "ranks the user's own values together with the popular ones" do
      user = create(:user)
      create(:collected_pen, user: user, brand: "Pebeo")
      create(:collected_pen, user: user, brand: "Pent")
      add_pens(3, brand: "Pelikan")
      add_pens(2, brand: "Pent")

      expect(search(:brand, "pe", user: user)).to eq(%w[Pelikan Pent Pebeo])
    end

    it "only includes models of the given brand" do
      add_pens(2, brand: "Pilot", model: "Custom 74")
      add_pens(2, brand: "Pilot Namiki", model: "Custom 823")
      add_pens(2, brand: "Sailor", model: "Pro Gear")

      expect(search(:model, "c", brand: " pilot ")).to eq(["Custom 74"])
    end

    it "only includes the user's own models of the given brand" do
      user = create(:user)
      create(:collected_pen, user: user, brand: "Pilot", model: "Custom Heritage")
      create(:collected_pen, user: user, brand: "Sailor", model: "Custom Pro")

      expect(search(:model, "custom", user: user, brand: "pilot")).to eq(["Custom Heritage"])
      expect(search(:model, "custom", user: user)).to eq(["Custom Heritage", "Custom Pro"])
    end

    it "merges the same model across brands when no brand is given" do
      add_pens(1, brand: "Pilot", model: "Custom 74")
      add_pens(2, brand: "Namiki", model: "custom 74")
      add_pens(2, brand: "Pilot", model: "Custom 823")

      expect(search(:model, "custom")).to eq(["custom 74", "Custom 823"])
    end

    it "returns results even when there are many matches" do
      20.times { |i| add_pens(2, model: "Model #{i}") }

      expect(search(:model, "mod").length).to eq(AutocompleteRanking::LIMIT)
    end

    it "rejects unsupported fields" do
      expect { described_class.autocomplete_search("x", :nib, user: create(:user)) }.to raise_error(
        ArgumentError
      )
    end
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

    it "counts the users per model, per brand and across all brands" do
      user = create(:user)
      create(:collected_pen, user: user, brand: "Pilot", model: "Custom 74")
      create(:collected_pen, user: user, brand: "Namiki", model: "Custom 74")
      create(:collected_pen, brand: "Pilot", model: "Custom 74")

      described_class.refresh

      expect(rows("model")).to eq(
        [
          ["", "custom 74", "Custom 74", 2],
          ["namiki", "custom 74", "Custom 74", 1],
          ["pilot", "custom 74", "Custom 74", 2]
        ]
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
