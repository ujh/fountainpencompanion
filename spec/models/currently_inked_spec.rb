require "rails_helper"

describe CurrentlyInked do
  subject { described_class.new(user: user) }

  let(:user) { create(:user) }

  describe "validations" do
    it "fails if the ink belongs to another user" do
      subject.collected_ink = create(:collected_ink)
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_ink)
    end

    it "validates if the ink belongs to the same user" do
      subject.collected_ink = create(:collected_ink, user: user)
      expect(subject).to be_invalid
      expect(subject.errors).to_not include(:collected_ink)
    end

    it "fails if the pen belongs to another user" do
      subject.collected_pen = create(:collected_pen)
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_pen)
    end

    it "validates if the pen belongs to the same user" do
      subject.collected_pen = create(:collected_pen, user: user)
      expect(subject).to be_invalid
      expect(subject.errors).to_not include(:collected_pen)
    end

    it "fails if the pen is already in use" do
      pen = create(:collected_pen, user: user)
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: create(:collected_ink, user: user)
      )
      subject.collected_pen = pen
      expect(subject).to be_invalid
      expect(subject.errors).to include(:collected_pen_id)
    end

    it "validates if the pen is only in an archived entry" do
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

  describe "#initialize" do
    it "sets a default inked_on" do
      expect(subject.inked_on).to eq(Date.today)
    end

    it "does not override an existing inked_on" do
      date = Date.yesterday
      ci = CurrentlyInked.new(inked_on: date)
      expect(ci.inked_on).to eq(date)
    end
  end

  it "marks the attached ink as used after a save" do
    user = create(:user)
    subject.user = user
    subject.collected_ink = create(:collected_ink, user: user)
    subject.collected_pen = create(:collected_pen, user: user)
    subject.inked_on = Date.today
    subject.save!
    expect(subject.collected_ink.reload.used).to be_truthy
  end

  describe "#collected_pens_for_active_select" do
    let(:pen) { create(:collected_pen, user: user) }
    let(:all_pens) { [pen, create(:collected_pen, user: user, brand: "Pilot", model: "Custom 74")] }

    before { all_pens }

    it "includes pens that are active" do
      expect(subject.collected_pens_for_active_select).to match_array(all_pens)
    end

    it "does not include pens that have an active currently inked" do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: create(:collected_ink, user: user)
      )
      expect(subject.collected_pens_for_active_select).to match_array(all_pens - [pen])
    end

    it "includes pens that have an archived currently inked" do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: create(:collected_ink, user: user),
        archived_on: Date.today
      )
      expect(subject.collected_pens_for_active_select).to match_array(all_pens)
    end

    it "includes the pen for this currently inked" do
      user.currently_inkeds.create!(
        collected_pen: pen,
        collected_ink: create(:collected_ink, user: user)
      )
      subject.collected_pen = pen
      expect(subject.collected_pens_for_active_select).to match_array(all_pens)
    end
  end

  describe "#last_used_on" do
    subject { create(:currently_inked) }

    it "returns the date of latest usage record" do
      create(:usage_record, currently_inked: subject, used_on: 1.day.ago)
      create(:usage_record, currently_inked: subject, used_on: 4.day.ago)

      expect(subject.last_used_on).to eq(1.day.ago.to_date)
    end

    it "returns the latest usage of the previous CI record if current one blank" do
      previous_ci =
        create(
          :currently_inked,
          user: subject.user,
          collected_ink: subject.collected_ink,
          collected_pen: subject.collected_pen,
          archived_on: Date.today
        )

      create(:usage_record, currently_inked: previous_ci, used_on: 1.day.ago)
      create(:usage_record, currently_inked: previous_ci, used_on: 4.day.ago)

      expect(subject.last_used_on).to eq(1.day.ago.to_date)
    end

    it "uses the latest usage record if present, even if previous entry has records as well" do
      create(:usage_record, currently_inked: subject, used_on: 2.day.ago)

      previous_ci =
        create(
          :currently_inked,
          user: subject.user,
          collected_ink: subject.collected_ink,
          collected_pen: subject.collected_pen,
          archived_on: Date.today
        )
      create(:usage_record, currently_inked: previous_ci, used_on: 1.day.ago)

      expect(subject.last_used_on).to eq(2.day.ago.to_date)
    end

    it "does not use the data from two ci entries back" do
      create(
        :currently_inked,
        user: subject.user,
        collected_ink: subject.collected_ink,
        collected_pen: subject.collected_pen,
        archived_on: Date.today,
        created_at: 2.days.ago
      )
      prev_prev_ci =
        create(
          :currently_inked,
          user: subject.user,
          collected_ink: subject.collected_ink,
          collected_pen: subject.collected_pen,
          archived_on: 2.days.ago,
          created_at: 3.days.ago
        )
      create(:usage_record, currently_inked: prev_prev_ci, used_on: 3.day.ago)

      expect(subject.last_used_on).to be nil
    end
  end

  describe "#refill!" do
    let(:ink) { create(:collected_ink, user: user) }
    let(:pen) { create(:collected_pen, user: user) }

    before do
      subject.collected_pen = pen
      subject.collected_ink = ink
      subject.save!
    end

    it "archives the entry and creates a new one" do
      expect do subject.refill! end.to change { user.currently_inkeds.count }.by(1)
      expect(subject).to be_archived
      newest_ci = user.currently_inkeds.last
      expect(newest_ci.collected_ink).to eq(ink)
      expect(newest_ci.collected_pen).to eq(pen)
      expect(newest_ci.inked_on).to eq(Date.today)
      expect(newest_ci).to be_active
    end

    it "raises an error if the ink is archived" do
      ink.archive!
      expect do
        expect { subject.refill! }.to_not(change { CurrentlyInked.count })
      end.to raise_error(CurrentlyInked::NotRefillable)
    end

    it "raises and error if the pen is archived" do
      pen.archive!
      expect do
        expect { subject.refill! }.to_not(change { CurrentlyInked.count })
      end.to raise_error(CurrentlyInked::NotRefillable)
    end
  end

  describe "#refillable?" do
    let(:ink) { create(:collected_ink, user: user) }
    let(:pen) { create(:collected_pen, user: user) }

    before do
      subject.collected_pen = pen
      subject.collected_ink = ink
    end

    it "returns true if both ink and pen are active" do
      expect(subject).to be_refillable
    end

    it "returns false if ink archived" do
      ink.archive!
      expect(subject).to_not be_refillable
    end

    it "returns false if pen archived" do
      pen.archive!
      expect(subject).to_not be_refillable
    end
  end

  describe "nib" do
    let(:ink) { create(:collected_ink, user: user) }
    let(:pen) { create(:collected_pen, user: user, brand: "Pilot", model: "Custom 74", nib: "M") }

    before do
      subject.collected_pen = pen
      subject.collected_ink = ink
      subject.save!
    end

    it "sets the nib if entry is archived" do
      expect do subject.update(archived_on: Date.today) end.to change { subject.nib }.from("").to(
        pen.nib
      )
    end

    it "does not change the nib when already archived" do
      subject.update(archived_on: Date.today)
      subject.update(nib: "other value")
      expect(subject.nib).to eq("other value")
      expect { subject.update(comment: "new comment") }.to_not(
        change do
          subject.reload
          subject.nib
        end
      )
    end

    it "clears the nib when unarchiving" do
      subject.update(archived_on: Date.today)
      expect do subject.update(archived_on: nil) end.to change { subject.nib }.from(pen.nib).to("")
    end
  end

  describe "#pen_name" do
    before do
      subject.collected_pen =
        create(
          :collected_pen,
          user: user,
          brand: "Pilot",
          model: "Custom 74",
          nib: "M",
          color: "orange"
        )
    end

    it "uses the nib from the pen" do
      expect(subject.pen_name).to eq("Pilot Custom 74, orange, plastic, gold, M")
    end

    it "uses the nib from self" do
      subject.nib = "my nib"
      expect(subject.pen_name).to eq("Pilot Custom 74, orange, plastic, gold, my nib")
    end
  end

  describe "#destroy" do
    subject { create(:currently_inked) }

    it "deletes usage records" do
      create(:usage_record, currently_inked: subject)
      expect do
        expect do subject.destroy end.to change { CurrentlyInked.count }.from(1).to(0)
      end.to change { UsageRecord.count }.from(1).to(0)
    end
  end

  describe "#used_today?" do
    subject { create(:currently_inked) }

    it "returns false if there is no UsageRecord" do
      expect(subject).to_not be_used_today
    end

    it "returns true when there is a UsageRecord for today" do
      create(:usage_record, currently_inked: subject, used_on: Date.today)
      expect(subject).to be_used_today
    end

    it "returns false when there is a UsageRecord for yesterday" do
      create(:usage_record, currently_inked: subject, used_on: Date.yesterday)
      expect(subject).to_not be_used_today
    end

    it "returns false when there is a UsageRecord for another currently inked" do
      create(:usage_record)
      expect(subject).to_not be_used_today
    end
  end

  describe "#collected_inks_for_active_select" do
    it "includes the current ink even if it is archived" do
      currently_inked = create(:currently_inked)
      currently_inked.collected_ink.archive!
      expect(currently_inked.collected_inks_for_active_select).to include(
        currently_inked.collected_ink
      )
    end
  end

  describe "#daily_usage_count" do
    subject(:currently_inked) { create(:currently_inked) }

    it "returns the correct number" do
      create(:usage_record, currently_inked: currently_inked)

      expect(currently_inked.daily_usage_count).to eq(1)
    end

    it "works when there are no records" do
      expect(currently_inked.daily_usage_count).to eq(0)
    end
  end

  describe "#unarchivable?" do
    subject(:currently_inked) { create(:currently_inked, archived_on: 1.day.ago) }

    it "returns true if the pen is unused and in the collection" do
      expect(currently_inked).to be_unarchivable
    end

    it "returns false if the pen has been archived" do
      currently_inked.collected_pen.archive!

      expect(currently_inked).not_to be_unarchivable
    end

    it "returns false if the pen is in use in another currently inked entry" do
      create(:currently_inked, collected_pen: currently_inked.collected_pen)

      expect(currently_inked).not_to be_unarchivable
    end
  end
end
