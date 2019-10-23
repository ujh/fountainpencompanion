require 'rails_helper'

describe CurrentlyInked do
  subject { described_class.new(user: user) }

  let(:user) { create(:user) }

  describe 'validations' do
    it 'fails if the ink belongs to another user' do
      subject.collected_ink = create(:collected_ink)
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_ink)
    end

    it 'validates if the ink belongs to the same user' do
      subject.collected_ink = create(:collected_ink, user: user)
      expect(subject).to be_invalid
      expect(subject.errors).to_not include(:collected_ink)
    end

    it 'fails if the pen belongs to another user' do
      subject.collected_pen = create(:collected_pen)
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_pen)
    end

    it 'validates if the pen belongs to the same user' do
      subject.collected_pen = create(:collected_pen, user: user)
      expect(subject).to be_invalid
      expect(subject.errors).to_not include(:collected_pen)
    end

    it 'fails if the pen is already in use' do
      pen = create(:collected_pen, user: user)
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: create(:collected_ink, user: user)
      )
      subject.collected_pen = pen
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_pen_id)
    end

    it 'validates if the pen is only in an archived entry' do
      pen = create(:collected_pen, user: user)
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: create(:collected_ink, user: user),
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

  it 'marks the attached ink as used after a save' do
    user = create(:user)
    subject.user = user
    subject.collected_ink = create(:collected_ink, user: user)
    subject.collected_pen = create(:collected_pen, user: user)
    subject.inked_on = Date.today
    subject.save!
    expect(subject.collected_ink.reload.used).to be_truthy
  end

  describe '#collected_pens_for_active_select' do
    let(:pen) { create(:collected_pen, user: user) }
    let(:all_pens) do
      [
        pen,
        create(:collected_pen, user: user, brand: 'Pilot', model: 'Custom 74')
      ]
    end

    before { all_pens }

    it 'includes pens that are active' do
      expect(subject.collected_pens_for_active_select).to match_array(all_pens)
    end

    it 'does not include pens that have an active currently inked' do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: create(:collected_ink, user: user)
      )
      expect(subject.collected_pens_for_active_select).to match_array(all_pens - [pen])
    end

    it 'includes pens that have an archived currently inked' do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: create(:collected_ink, user: user),
        archived_on: Date.today
      )
      expect(subject.collected_pens_for_active_select).to match_array(all_pens)
    end

    it 'includes the pen for this currently inked' do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: create(:collected_ink, user: user)
      )
      subject.collected_pen = pen
      expect(subject.collected_pens_for_active_select).to match_array(all_pens)
    end
  end

  describe "nib" do
    let(:ink) { create(:collected_ink, user: user) }
    let(:pen) { create(:collected_pen, user: user, brand: 'Pilot', model: 'Custom 74', nib: 'M') }

    before do
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
    before do
      subject.collected_pen = create(:collected_pen, user: user, brand: 'Pilot', model: 'Custom 74', nib: 'M', color: 'orange')
    end

    it 'uses the nib from the pen' do
      expect(subject.pen_name).to eq('Pilot Custom 74 M orange')
    end

    it 'uses the nib from self' do
      subject.nib = 'my nib'
      expect(subject.pen_name).to eq('Pilot Custom 74 my nib orange')
    end
  end

  describe '#destroy' do

    subject { create(:currently_inked) }

    it 'deletes usage records' do
      usage_record = create(:usage_record, currently_inked: subject)
      expect do
        expect do
          subject.destroy
        end.to change { CurrentlyInked.count }.from(1).to(0)
      end.to change { UsageRecord.count }.from(1).to(0)
    end
  end

  describe '#used_today?' do

    subject { create(:currently_inked) }

    it 'returns false if there is no UsageRecord' do
      expect(subject).to_not be_used_today
    end

    it 'returns true when there is a UsageRecord for today' do
      usage_record = create(:usage_record, currently_inked: subject)
      expect(subject).to be_used_today
    end

    it 'returns false when there is a UsageRecord for yesterday' do
      usage_record = create(:usage_record, currently_inked: subject, used_on: Date.yesterday)
      expect(subject).to_not be_used_today
    end

    it 'returns false when there is a UsageRecord for another currently inked' do
      usage_record = create(:usage_record)
      expect(subject).to_not be_used_today
    end
  end
end
