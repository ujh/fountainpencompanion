require 'rails_helper'

describe CollectedInk do
  it 'requires an associated user' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:user)
  end

  it 'requires an ink name' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:ink_name)
  end

  it 'requires a brand name' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:brand_name)
  end

  describe 'uniqueness' do
    fixtures :collected_inks, :users

    let(:existing_ink) { collected_inks(:monis_syrah) }

    it 'is not allowed to create a duplicate collected ink for the same user' do
      new_ink = CollectedInk.new(
        user_id: existing_ink.user_id,
        brand_name: existing_ink.brand_name,
        line_name: existing_ink.line_name,
        ink_name: existing_ink.ink_name,
        kind: existing_ink.kind,
      )
      expect(new_ink).to_not be_valid
    end

    it 'is allowed to have the same ink with a different kind' do
      existing_ink.update_attributes!(kind: 'bottle')
      new_ink = CollectedInk.new(
        user_id: existing_ink.user_id,
        brand_name: existing_ink.brand_name,
        line_name: existing_ink.line_name,
        ink_name: existing_ink.ink_name,
        kind: 'sample',
      )
      expect(new_ink).to be_valid
    end

    it 'is allowed to create the same ink for another user' do
      new_ink = CollectedInk.new(
        user_id: users(:tom).id,
        brand_name: existing_ink.brand_name,
        line_name: existing_ink.line_name,
        ink_name: existing_ink.ink_name
      )
      expect(new_ink).to be_valid
    end

    it 'is not allowed to create a collected ink that only differs in case' do
      new_ink = CollectedInk.new(
        user_id: existing_ink.user_id,
        brand_name: existing_ink.brand_name.upcase,
        line_name: existing_ink.line_name,
        ink_name: existing_ink.ink_name,
        kind: existing_ink.kind,
      )
      expect(new_ink).to_not be_valid
    end

  end

  context 'simplified fields' do

    fixtures :users
    let(:collected_ink) do
      CollectedInk.create!(
        user_id: users(:moni).id,
        brand_name: 'Sailor',
        line_name: 'Jentle',
        ink_name: 'Doyou'
      )
    end

    it 'populates before save' do
      expect(collected_ink.simplified_brand_name).to eq('sailor')
      expect(collected_ink.simplified_line_name).to eq('jentle')
      expect(collected_ink.simplified_ink_name).to eq('doyou')
    end

    it 'does not change the fields when validation fails' do
      collected_ink.brand_name = ''
      collected_ink.save
      expect(collected_ink.simplified_brand_name).to eq('sailor')
      expect(collected_ink.simplified_line_name).to eq('jentle')
      expect(collected_ink.simplified_ink_name).to eq('doyou')
    end
  end

  describe '#brand_count' do

    fixtures :users

    let(:user) { User.first }

    before(:each) do
      CollectedInk.delete_all
      CollectedInk.create!(user_id: user.id, brand_name: 'Diamine', ink_name: 'A')
      CollectedInk.create!(user_id: user.id, brand_name: 'diamine', ink_name: 'B')
      CollectedInk.create!(user_id: user.id, brand_name: 'Sailor', ink_name: 'C')
    end

    it 'returns the number of unique brands' do
      expect(described_class.brand_count).to eq(2)
    end
  end

  describe '#to_csv' do

    fixtures :collected_inks, :collected_pens, :users

    let(:collected_ink) { collected_inks(:monis_fire_and_ice) }
    let(:csv) do
      CSV.parse(CollectedInk.where(id: [collected_ink.id]).to_csv, headers: true, col_sep: ";")
    end
    let(:entry) { csv.first }

    it 'has a header row' do
      expect(CollectedInk.none.to_csv).to eq("Brand;Line;Name;Type;Color;Swabbed;Used;Comment;Archived;Usage\n")
    end

    it 'has the correct brand' do
      expect(entry["Brand"]).to eq("Robert Oster")
    end

    it 'has the correct line' do
      expect(entry["Line"]).to eq("Signature")
    end

    it 'has the correct name' do
      expect(entry["Name"]).to eq("Fire & Ice")
    end

    it 'has the correct type' do
      expect(entry["Type"]).to eq("bottle")
    end

    it 'has the correct color' do
      collected_ink.update(color: '#cdcdcd')
      expect(entry["Color"]).to eq('#cdcdcd')
    end

    it 'has the correct value for swabbed' do
      collected_ink.update(swabbed: true)
      expect(entry["Swabbed"]).to eq('true')
    end

    it 'has the correct value for used' do
      collected_ink.update(used: true)
      expect(entry["Used"]).to eq('true')
    end

    it 'has the correct comment' do
      collected_ink.update(comment: 'comment')
      expect(entry['Comment']).to eq('comment')
    end

    it 'has the correct value for archived' do
      collected_ink.update(archived_on: Date.today)
      expect(entry['Archived']).to eq('true')
    end

    it 'has the correct value for Usage' do
      CurrentlyInked.create!(
        collected_ink: collected_ink,
        collected_pen: collected_pens(:monis_wing_sung),
        user: collected_ink.user
      )
      CurrentlyInked.create!(
        collected_ink: collected_ink,
        collected_pen: collected_pens(:monis_pilot_custom_74),
        user: collected_ink.user,
        archived_on: Date.today
      )
      expect(entry['Usage']).to eq('2')
    end
  end
end
