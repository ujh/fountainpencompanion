require 'rails_helper'

describe CollectedPen do
  it 'requires an associated user' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:user)
  end

  it 'requires an brand' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:brand)
  end

  it 'requires a model' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:model)
  end

  describe '#name' do
    it 'combines brand, model, nib, and color' do
      subject.brand = 'brand'
      subject.model = 'model'
      subject.nib = 'nib'
      subject.color = 'color'
      expect(subject.name).to eq('brand model, color, nib')
    end

    it 'leaves out empty fields' do
      subject.brand = 'brand'
      subject.model = 'model'
      expect(subject.name).to eq('brand model')
    end
  end

  describe '#search' do
    let(:pens) do
      [
        create(:collected_pen),
        create(:collected_pen, brand: 'Platinum', model: '3776', nib: 'XF', color: 'pink'),
        create(:collected_pen, brand: 'Pilot', model: 'Custom 74', nib: 'M', color: 'orange')
      ]
    end

    before { pens }
    it 'finds matching entries by substring search' do
      expect(described_class.search(:brand, 'P')).to eq(["Pilot", "Platinum"])
    end
  end

  describe '#to_csv' do
    let(:collected_pen) { create(:collected_pen, brand: 'Pilot', model: 'Custom 74', nib: 'M', color: 'orange') }
    let(:csv) do
      CSV.parse(described_class.where(id: [collected_pen.id]).to_csv, headers: true, col_sep: ";")
    end
    let(:entry) { csv.first }

    it 'has a header row' do
      expect(described_class.none.to_csv).to eq("Brand;Model;Nib;Color;Comment;Archived;Archived On;Usage;Last Inked;Last Cleaned\n")
    end

    it 'has the correct brand' do
      expect(entry["Brand"]).to eq("Pilot")
    end

    it 'has the correct model' do
      expect(entry["Model"]).to eq("Custom 74")
    end

    it 'has the correct Nib' do
      expect(entry["Nib"]).to eq("M")
    end

    it 'has the correct Color' do
      expect(entry["Color"]).to eq("orange")
    end

    it 'has the correct Comment' do
      collected_pen.update(comment: 'comment')
      expect(entry["Comment"]).to eq("comment")
    end

    it 'has the correct value when archived' do
      collected_pen.update(archived_on: Date.today)
      expect(entry["Archived"]).to eq("true")
    end

    it 'has the correct value when not archived' do
      collected_pen.update(archived_on: nil)
      expect(entry["Archived"]).to eq("false")
    end

    it 'has the correct value for archived on' do
      date = Date.today
      collected_pen.update(archived_on: date)
      expect(entry["Archived On"]).to eq(date.to_s(:db))
    end

    it 'has the correct value for Usage' do
      CurrentlyInked.create!(
        collected_ink: create(:collected_ink, user: collected_pen.user, ink_name: 'Twilight'),
        collected_pen: collected_pen,
        user: collected_pen.user
      )
      CurrentlyInked.create!(
        collected_ink: create(:collected_ink, user: collected_pen.user, ink_name: 'Pumpkin'),
        collected_pen: collected_pen,
        user: collected_pen.user,
        archived_on: Date.today
      )
      expect(entry['Usage']).to eq('2')
    end
  end
end
