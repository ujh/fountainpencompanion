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
end
