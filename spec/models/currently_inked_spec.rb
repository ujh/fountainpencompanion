require 'rails_helper'

describe CurrentlyInked do

  fixtures :users, :collected_inks, :collected_pens

  let(:user) { users(:moni) }

  before(:each) do
    subject.user = users(:moni)
  end

  describe 'validations' do

    it 'fails if the ink belongs to another user' do
      subject.collected_ink = collected_inks(:toms_marine)
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_ink)
    end

    it 'validates if the ink belongs to the same user' do
      subject.collected_ink = collected_inks(:monis_marine)
      expect(subject).to be_invalid
      expect(subject.errors).to_not include(:collected_ink)
    end

    it 'fails if the pen belongs to another user' do
      subject.collected_pen = collected_pens(:toms_platinum)
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_pen)
    end

    it 'validates if the pen belongs to the same user' do
      subject.collected_pen = collected_pens(:monis_wing_sung)
      expect(subject).to be_invalid
      expect(subject.errors).to_not include(:collected_pen)
    end

    it 'fails if the pen is already in use' do
      pen = collected_pens(:monis_wing_sung)
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: collected_inks(:monis_marine)
      )
      subject.collected_pen = pen
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_pen_id)
    end

    it 'validates if the pen is only in an archived entry' do
      pen = collected_pens(:monis_wing_sung)
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: collected_inks(:monis_marine),
        archived_on: Date.today
      )
      subject.collected_pen = pen
      expect(subject).to be_invalid
      expect(subject.errors).to_not include(:collected_pen)
    end
  end

  describe '#initialize' do
    it 'sets a default inked_on' do
      expect(subject.inked_on).to eq(Date.today)
    end

    it 'does not override an existing inked_on' do
      date = Date.yesterday
      ci = CurrentlyInked.new(inked_on: date)
      expect(ci.inked_on).to eq(date)
    end
  end

  describe '#unarchivable?' do

    let(:pen) { collected_pens(:monis_wing_sung) }

    before(:each) do
      subject.update!(
        collected_pen: pen,
        collected_ink: collected_inks(:monis_fire_and_ice),
        archived_on: Date.today
      )
    end

    it 'returns false if there is an active currently inked with that pen' do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: collected_inks(:monis_marine)
      )
      expect(subject).to_not be_unarchivable
    end

    it 'returns true if there is an archived entry with that pen' do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: collected_inks(:monis_marine),
        archived_on: Date.today
      )
      expect(subject).to be_unarchivable
    end
  end

  describe '#collected_pens_for_active_select' do

    let(:pen) { collected_pens(:monis_wing_sung) }

    it 'includes pens that are active' do
      expect(subject.collected_pens_for_active_select).to match_array([
        collected_pens(:monis_wing_sung),
        collected_pens(:monis_pilot_custom_74)
      ])
    end

    it 'does not include pens that have an active currently inked' do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: collected_inks(:monis_marine)
      )
      expect(subject.collected_pens_for_active_select).to match_array([collected_pens(:monis_pilot_custom_74)])
    end

    it 'includes pens that have an archived currently inked' do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: collected_inks(:monis_marine),
        archived_on: Date.today
      )
      expect(subject.collected_pens_for_active_select).to match_array([
        collected_pens(:monis_wing_sung),
        collected_pens(:monis_pilot_custom_74)
      ])
    end

    it 'includes the pen for this currently inked' do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: collected_inks(:monis_marine)
      )
      subject.collected_pen = pen
      expect(subject.collected_pens_for_active_select).to match_array([
        collected_pens(:monis_wing_sung),
        collected_pens(:monis_pilot_custom_74)
      ])
    end
  end

  describe "nib" do

    let(:ink) { collected_inks(:monis_marine) }
    let(:pen) { collected_pens(:monis_pilot_custom_74) }

    before(:each) do
      subject.collected_pen = pen
      subject.collected_ink = ink
      subject.save!
    end

    it 'sets the nib if entry is archived' do
      expect do
        subject.update(archived_on: Date.today)
      end.to change { subject.nib }.from("").to(pen.nib)
    end

    it 'does not change the nib when already archived' do
      subject.update(archived_on: Date.today)
      subject.update(nib: "other value")
      expect(subject.nib).to eq("other value")
      expect do
        subject.update(comment: 'new comment')
      end.to_not change { subject.reload; subject.nib }
    end

    it 'clears the nib when unarchiving' do
      subject.update(archived_on: Date.today)
      expect do
        subject.update(archived_on: nil)
      end.to change { subject.nib }.from(pen.nib).to("")
    end
  end

  describe '#pen_name' do
    before(:each) do
      subject.collected_pen = collected_pens(:monis_pilot_custom_74)
    end

    it 'uses the nib from the pen' do
      expect(subject.pen_name).to eq('Pilot Custom 74 M orange')
    end

    it 'uses the nib from self' do
      subject.nib = 'my nib'
      expect(subject.pen_name).to eq('Pilot Custom 74 my nib orange')
    end
  end
end
