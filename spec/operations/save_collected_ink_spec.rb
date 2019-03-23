require 'rails_helper'

describe SaveCollectedInk do

  def add!(params)
    ci = CollectedInk.new(user: create(:user))
    SaveCollectedInk.new(ci, params).perform
    ci
  end

  def default!(params = {})
    add!({
      brand_name: 'Pilot', line_name: 'Iroshizuku', ink_name: 'Kon-Peki'
    }.merge(params))
  end

  it 'works with two distinct inks from the same manufacturer' do
    ci1 = default!
    ci2 = default!(ink_name: 'Shin-Kai')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to_not eq(ci2.new_ink_name)
  end

  it 'uses same brand cluster for two distinct inks with similar brand name' do
    ci1 = default!
    ci2 = default!(brand_name: 'PilotX', ink_name: 'Shin-Kai')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to_not eq(ci2.new_ink_name)
  end

  it 'clusters two inks with the same name' do
    ci1 = default!
    ci2 = default!
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand names are similar' do
    ci1 = default!
    ci2 = default!(brand_name: 'PilotX')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters when line name is missing' do
    ci1 = default!
    ci2 = add!(brand_name: 'Pilot', ink_name: 'Kon-Peki')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name is different' do
    ci1 = default!
    ci2 = add!(brand_name: 'Pilot', line_name: 'completely different', ink_name: 'Kon-Peki')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name and brand name match' do
    ci0 = default!
    ci1 = default!
    ci2 = add!(brand_name: 'Iroshizuku', ink_name: 'Kon-Peki')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name and brand name are similar' do
    ci0 = default!
    ci1 = default!
    ci2 = add!(brand_name: 'IroshizukuX', ink_name: 'Kon-Peki')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name and brand name match (switch order of addition)' do
    ci2 = add!(brand_name: 'Iroshizuku', ink_name: 'Kon-Peki')
    ci1 = default!
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name and brand name are similar (switch order of addition)' do
    ci2 = add!(brand_name: 'IroshizukuX', ink_name: 'Kon-Peki')
    ci1 = default!
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand and line name are in the brands field' do
    ci1 = default!
    ci2 = add!(brand_name: 'Pilot Iroshizuku', ink_name: 'Kon-Peki')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand and line name are in the brands field and are similar' do
    ci1 = default!
    ci2 = add!(brand_name: 'Pilot IroshizukuX', ink_name: 'Kon-Peki')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand and line name are in the brands field (switch order of addition)' do
    ci0 = default!
    ci2 = add!(brand_name: 'Pilot Iroshizuku', ink_name: 'Kon-Peki')
    ci1 = default!
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand and line name are in the brands field and are similar (switch order of addition)' do
    ci0 = default!
    ci2 = add!(brand_name: 'Pilot IroshizukuX', ink_name: 'Kon-Peki')
    ci1 = default!
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'merges clusters' do
    ci1 = add!(brand_name: 'Pilot', ink_name: 'Kon-Peki')
    ci2 = add!(brand_name: 'Iroshizuku', ink_name: 'Kon-Peki')
    expect(ci1.ink_brand).to_not eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to_not eq(ci2.new_ink_name)
    # This will match both and link them together
    ci3 = add!(brand_name: 'Pilot', line_name: 'Iroshizuku', ink_name: 'Kon-Peki')
    [ci1, ci2].map(&:reload)
    expect(ci3.ink_brand).to eq(ci1.ink_brand)
    expect(ci3.ink_brand).to eq(ci2.ink_brand)
    expect(ci3.new_ink_name).to eq(ci1.new_ink_name)
    expect(ci3.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'picks the brand with the most members' do
    ci1 = default!
    ci2 = default!
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
    expect(ci1.ink_brand.simplified_name).to eq('pilot')
    # Now add three with Iroshizuku. It should the change to use Iroshizuku as
    # the brand.
    expect do
      ci3 = add!(brand_name: 'Iroshizuku', ink_name: 'Kon-Peki')
      ci4 = add!(brand_name: 'Iroshizuku', ink_name: 'Kon-Peki')
      ci5 = add!(brand_name: 'Iroshizuku', ink_name: 'Kon-Peki')
      inks = [ci1, ci2, ci3, ci4, ci5]
      inks.map(&:reload)
      ink_brand = ci3.ink_brand
      new_ink_name = ci3.new_ink_name
      expect(ink_brand.collected_inks).to match_array([ci1, ci2, ci3, ci4, ci5])
      expect(new_ink_name.collected_inks).to match_array([ci1, ci2, ci3, ci4, ci5])
      expect(ink_brand.simplified_name).to eq('iroshizuku')
    end.to change { InkBrand.count }.by(1)
  end

  it 'splits clusters' do
    ci1 = add!(brand_name: 'Diamine', ink_name: 'Coral')
    ci2 = create(:collected_ink, {
      brand_name: 'Levenger',
      ink_name: 'Regal',
      ink_brand: ci1.ink_brand,
      new_ink_name: ci1.new_ink_name
    })
    ci3 = add!(brand_name: 'Diamine', ink_name: 'Coral') # Needs to remove ci2
    [ci1, ci2, ci3].map(&:reload)
    expect(ci1.ink_brand).to eq(ci3.ink_brand)
    expect(ci1.new_ink_name).to eq(ci3.new_ink_name)
    expect(ci1.ink_brand.popular_name).to eq('Diamine')
    expect(ci1.new_ink_name.popular_name).to eq('Coral')
    expect(ci2.ink_brand).to_not eq(ci1.ink_brand)
    expect(ci2.new_ink_name).to_not eq(ci1.new_ink_name)
    expect(ci2.ink_brand.popular_name).to eq('Levenger')
    expect(ci2.new_ink_name.popular_name).to eq('Regal')
  end
end
