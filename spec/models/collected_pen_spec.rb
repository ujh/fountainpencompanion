require "rails_helper"

describe CollectedPen do
  it "requires an associated user" do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:user)
  end

  it "requires an brand" do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:brand)
  end

  it "requires a model" do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:model)
  end

  describe "#name" do
    it "combines brand, model, nib, and color" do
      subject.brand = "brand"
      subject.model = "model"
      subject.nib = "nib"
      subject.color = "color"
      expect(subject.name).to eq("brand model, color, nib")
    end

    it "leaves out empty fields" do
      subject.brand = "brand"
      subject.model = "model"
      expect(subject.name).to eq("brand model")
    end
  end

  it "deletes all linked currently inked entries when deleting a model" do
    pen = create(:collected_pen)
    create(:currently_inked, collected_pen: pen)
    create(:currently_inked, collected_pen: pen, archived_on: Date.today)
    expect { pen.destroy }.to change(CurrentlyInked, :count).by(-2)
  end

  describe ".autocomplete_search" do
    def add_pens(count, **attributes)
      count.times { create(:collected_pen, **attributes) }
    end

    it "ranks values by match quality and then by number of users" do
      add_pens(1, brand: "Platinum")
      add_pens(2, brand: "Pilot")
      add_pens(3, brand: "Kaweco Sport")
      add_pens(3, brand: "Pelikan")

      expect(described_class.autocomplete_search("p", :brand)).to eq(
        ["Pelikan", "Pilot", "Platinum", "Kaweco Sport"]
      )
    end

    it "counts users instead of pens" do
      user = create(:user)
      3.times { create(:collected_pen, user: user, brand: "Platinum") }
      add_pens(2, brand: "Pilot")

      expect(described_class.autocomplete_search("p", :brand)).to eq(%w[Pilot Platinum])
    end

    it "merges values that only differ in case or surrounding spaces" do
      add_pens(2, brand: "Pilot")
      add_pens(1, brand: "pilot ")

      expect(described_class.autocomplete_search("pil", :brand)).to eq(["Pilot"])
    end

    it "returns results even when there are many matches" do
      150.times { |i| create(:collected_pen, model: "Model #{i}") }

      expect(described_class.autocomplete_search("mod", :model).length).to eq(
        AutocompleteRanking::LIMIT
      )
    end

    it "finds values with typos" do
      add_pens(1, brand: "Pelikan")

      expect(described_class.autocomplete_search("pelican", :brand)).to eq(["Pelikan"])
    end

    it "ignores empty values" do
      add_pens(1, nib: "")
      create(:collected_pen).update_column(:nib, nil)

      expect(described_class.autocomplete_search("", :nib)).to eq([])
    end

    it "respects the current scope" do
      user = create(:user)
      create(:collected_pen, user: user, nib: "Fine")
      add_pens(1, nib: "Fude")

      expect(user.collected_pens.autocomplete_search("f", :nib)).to eq(["Fine"])
    end

    it "rejects unsupported fields" do
      expect { described_class.autocomplete_search("x", :comment) }.to raise_error(ArgumentError)
    end
  end

  describe "#to_csv" do
    let(:collected_pen) do
      create(:collected_pen, brand: "Pilot", model: "Custom 74", nib: "M", color: "orange")
    end
    let(:csv) do
      CSV.parse(described_class.where(id: [collected_pen.id]).to_csv, headers: true, col_sep: ";")
    end
    let(:entry) { csv.first }

    it "has a header row" do
      expect(described_class.none.to_csv).to eq(
        "Brand;Model;Nib;Color;Material;Trim Color;Filling System;Price;Comment;Archived;Archived On;Usage;Daily Usage;Last Inked;Last Cleaned;Last Used;Inked;Date Added\n"
      )
    end

    it "has the correct brand" do
      expect(entry["Brand"]).to eq("Pilot")
    end

    it "has the correct model" do
      expect(entry["Model"]).to eq("Custom 74")
    end

    it "has the correct Nib" do
      expect(entry["Nib"]).to eq("M")
    end

    it "has the correct Color" do
      expect(entry["Color"]).to eq("orange")
    end

    it "has the correct Comment" do
      collected_pen.update(comment: "comment")
      expect(entry["Comment"]).to eq("comment")
    end

    it "has the correct value when archived" do
      collected_pen.update(archived_on: Date.today)
      expect(entry["Archived"]).to eq("true")
    end

    it "has the correct value when not archived" do
      collected_pen.update(archived_on: nil)
      expect(entry["Archived"]).to eq("false")
    end

    it "has the correct value for archived on" do
      date = Date.today
      collected_pen.update(archived_on: date)
      expect(entry["Archived On"]).to eq(date.to_fs(:db))
    end

    it "has the correct value for Usage" do
      CurrentlyInked.create!(
        collected_ink: create(:collected_ink, user: collected_pen.user, ink_name: "Twilight"),
        collected_pen: collected_pen,
        user: collected_pen.user
      )
      CurrentlyInked.create!(
        collected_ink: create(:collected_ink, user: collected_pen.user, ink_name: "Pumpkin"),
        collected_pen: collected_pen,
        user: collected_pen.user,
        archived_on: Date.today
      )
      expect(entry["Usage"]).to eq("2")
    end
  end

  describe "#usage_count" do
    subject(:pen) { create(:collected_pen) }

    it "returns the correct number" do
      ci = create(:currently_inked, collected_pen: pen)
      expect(pen.usage_count).to eq(1)
    end

    it "works when there are no entries" do
      expect(pen.usage_count).to eq(0)
    end
  end

  describe "#daily_usage_count" do
    subject(:pen) { create(:collected_pen) }

    it "returns the correct number" do
      ci = create(:currently_inked, collected_pen: pen)
      create(:usage_record, currently_inked: ci)
      expect(pen.daily_usage_count).to eq(1)
    end

    it "works when there are no entries" do
      expect(pen.daily_usage_count).to eq(0)
    end
  end

  describe "#last_inked" do
    subject(:pen) { create(:collected_pen) }

    it "returns the correct date" do
      ci =
        create(:currently_inked, collected_pen: pen, inked_on: 10.days.ago, archived_on: 3.days.ago)
      ci = create(:currently_inked, collected_pen: pen, inked_on: 2.days.ago)

      expect(pen.last_inked).to eq(2.days.ago.to_date)
    end

    it "works when there are no entries" do
      expect(pen.last_inked).to eq(nil)
    end
  end

  describe "#last_cleaned" do
    subject(:pen) { create(:collected_pen) }

    it "returns the correct date" do
      ci =
        create(:currently_inked, collected_pen: pen, inked_on: 10.days.ago, archived_on: 3.days.ago)
      ci =
        create(:currently_inked, collected_pen: pen, inked_on: 2.days.ago, archived_on: 1.day.ago)

      expect(pen.last_cleaned).to eq(1.day.ago.to_date)
    end

    it "returns nil when still inked" do
      ci = create(:currently_inked, collected_pen: pen, inked_on: 2.days.ago)
      expect(pen.last_cleaned).to eq(nil)
    end

    it "works when there are no entries" do
      expect(pen.last_cleaned).to eq(nil)
    end
  end

  describe "#last_used_on" do
    subject(:pen) { create(:collected_pen) }

    it "returns the correct date" do
      ci = create(:currently_inked, collected_pen: pen, inked_on: 30.days.ago.to_date)
      create(:usage_record, currently_inked: ci, used_on: 2.days.ago)

      expect(pen.last_used_on).to eq(2.days.ago.to_date)
    end

    it "works when there are no entries" do
      expect(pen.last_used_on).to eq(nil)
    end
  end

  describe "#inked?" do
    subject(:pen) { create(:collected_pen) }

    it "returns true when there is an active currently inked entry" do
      create(:currently_inked, collected_pen: pen)

      expect(pen).to be_inked
    end

    it "returns false when there is an archived currently inked entry" do
      create(:currently_inked, collected_pen: pen, inked_on: 2.days.ago, archived_on: 1.day.ago)

      expect(pen).not_to be_inked
    end

    it "works when there are no entries" do
      expect(pen).not_to be_inked
    end
  end
end
