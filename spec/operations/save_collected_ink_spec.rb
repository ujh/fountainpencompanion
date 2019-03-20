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
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to_not eq(ci2.new_ink_name)
  end

  it 'uses same brand cluster for two distinct inks with similar brand name' do
    ci1 = default!
    ci2 = default!(brand_name: 'PilotX', ink_name: 'Shin-Kai')
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to_not eq(ci2.new_ink_name)
  end

  it 'clusters two inks with the same name' do
    ci1 = default!
    ci2 = default!
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand names are similar' do
    ci1 = default!
    ci2 = default!(brand_name: 'PilotX')
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters when line name is missing' do
    ci1 = default!
    ci2 = add!(brand_name: 'Pilot', ink_name: 'Kon-Peki')
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name is different' do
    ci1 = default!
    ci2 = add!(brand_name: 'Pilot', line_name: 'completely different', ink_name: 'Kon-Peki')
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name and brand name match' do
    ci1 = default!
    ci2 = add!(brand_name: 'Iroshizuku', ink_name: 'Kon-Peki')
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name and brand name are similar' do
    ci1 = default!
    ci2 = add!(brand_name: 'IroshizukuX', ink_name: 'Kon-Peki')
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name and brand name match (switch order of addition)' do
    ci2 = add!(brand_name: 'Iroshizuku', ink_name: 'Kon-Peki')
    ci1 = default!
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if line name and brand name are similar (switch order of addition)' do
    ci2 = add!(brand_name: 'IroshizukuX', ink_name: 'Kon-Peki')
    ci1 = default!
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand and line name are in the brands field' do
    ci1 = default!
    ci2 = add!(brand_name: 'Pilot Iroshizuku', ink_name: 'Kon-Peki')
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand and line name are in the brands field and are similar' do
    ci1 = default!
    ci2 = add!(brand_name: 'Pilot IroshizukuX', ink_name: 'Kon-Peki')
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand and line name are in the brands field (switch order of addition)' do
    ci2 = add!(brand_name: 'Pilot Iroshizuku', ink_name: 'Kon-Peki')
    ci1 = default!
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end

  it 'clusters if brand and line name are in the brands field and are similar (switch order of addition)' do
    ci2 = add!(brand_name: 'Pilot IroshizukuX', ink_name: 'Kon-Peki')
    ci1 = default!
    expect(ci1.ink_brand).to eq(ci2.ink_brand)
    expect(ci1.new_ink_name).to eq(ci2.new_ink_name)
  end
end
