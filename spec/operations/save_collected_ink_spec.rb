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
  end

  pending 'splits clusters' do
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

  it 'combines inks with three different names into one cluster' do
    cis = []
    cis << add!(brand_name: 'Pilot Iroshizuku', ink_name: 'Fuyu-Syogun')
    cis << add!(brand_name: 'Pilot Iroshizuku', line_name: 'Iroshizuku', ink_name: 'Fuyu-Syogun')
    cis << add!(brand_name: 'Pilot', line_name: 'Iroshizuku', ink_name: 'Fuyu-Syogun')
    cis.map(&:reload)
    expect(cis.map(&:ink_brand).uniq.length).to eq(1)
    expect(cis.map(&:new_ink_name).uniq.length).to eq(1)
  end

  it 'combines inks with three different names into one cluster' do
    cis = []
    cis << add!(brand_name: 'Pilot Iroshizuku', ink_name: 'Fuyu-Syogun')
    cis << add!(brand_name: 'Pilot Iroshizuku', line_name: 'Iroshizuku', ink_name: 'Fuyu-Syogun')
    cis << add!(brand_name: 'Pilot', line_name: 'Iroshizuku', ink_name: 'Fuyu-Syogun')
    cis << add!(brand_name: 'Pilot', ink_name: 'Fuyu-Syogun')
    cis << add!(brand_name: 'Iroshizuku', ink_name: 'Fuyu-Syogun')
    cis.map(&:reload)
    expect(cis.map(&:ink_brand).uniq.length).to eq(1)
    expect(cis.map(&:new_ink_name).uniq.length).to eq(1)
  end

  it 'does not combine Ban Mi and Colte' do
    cis = []
    cis << add!(brand_name: 'Ban Mi', line_name: 'Color', ink_name: 'Black')
    cis << add!(brand_name: 'Ban Mi Color', line_name: 'Glitter', ink_name: 'Black')
    cis << add!(brand_name: 'Ban Mi', ink_name: 'Black')
    cis << add!(brand_name: 'Colte', ink_name: 'Black')
    cis << add!(brand_name: 'Ban Mi', ink_name: 'Black (Gorilla)')
    cis.map(&:reload)
    expect(cis.map(&:ink_brand).uniq.length).to eq(2)
    expect(cis.map(&:new_ink_name).uniq.length).to eq(2)
  end

  it 'does not combine Kobe and Krone' do
    ci1 = default!(brand_name: 'Kobe')
    ci2 = default!(brand_name: 'Krone')
    [ci1, ci2].map(&:reload)
    expect(ci1.ink_brand).to_not eq(ci2.ink_brand)
  end

  it 'does not combine Sepia, Seiran, and, Seiya' do
    cis = []
    cis << default!(ink_name: 'Sepia')
    cis << default!(ink_name: 'Seiran')
    cis << default!(ink_name: 'Seiya')
    cis.map(&:reload)
    expect(cis.map(&:new_ink_name).uniq.length).to eq(3)
  end

  it 'does not combine Sheaffer Skrip and Scribo' do
    cis = []
    cis << add!(brand_name: 'Sheaffer', line_name: 'Skrip', ink_name: 'Red')
    cis << add!(brand_name: 'Sheaffer', line_name: 'Scrip', ink_name: 'Red')
    cis << add!(brand_name: 'Scribo', ink_name: 'Red')
    cis.map(&:reload)
    expect(cis.map(&:ink_brand).uniq.length).to eq(2)
  end
end
