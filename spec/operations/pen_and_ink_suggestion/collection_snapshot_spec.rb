require "rails_helper"
require "active_record/testing/query_assertions"

RSpec.describe PenAndInkSuggestion::CollectionSnapshot do
  include RSpec::Rails::MinitestAssertionAdapter
  include ActiveSupport::Testing::Assertions
  include ActiveSupport::Testing::TimeHelpers
  include ActiveRecord::Assertions::QueryAssertions

  let(:user) { create(:user) }
  let(:today) { Date.current }

  def ink_it(pen, ink, inked_on:, archived_on: nil, used_on: [], **attributes)
    inking =
      create(
        :currently_inked,
        user:,
        collected_pen: pen,
        collected_ink: ink,
        inked_on:,
        archived_on:,
        **attributes
      )
    used_on.each { |date| create(:usage_record, currently_inked: inking, used_on: date) }
    inking
  end

  describe "#pens and #inks" do
    it "loads the user's active items only" do
      pen = create(:collected_pen, user:)
      ink = create(:collected_ink, user:)
      create(:collected_pen, user:, archived_on: today)
      create(:collected_ink, user:, archived_on: today)
      create(:collected_pen)
      create(:collected_ink)

      snapshot = described_class.new(user)

      expect(snapshot.pens).to eq([pen])
      expect(snapshot.inks).to eq([ink])
    end

    it "preloads tags and the micro, macro and brand clusters" do
      brand_cluster = create(:brand_cluster, description: "A brand")
      macro_cluster = create(:macro_cluster, brand_cluster:, tags: %w[blue], description: "Deep")
      micro_cluster = create(:micro_cluster, macro_cluster:)
      create(:collected_ink, user:, micro_cluster:, tags_as_string: "shimmer, favourite")
      snapshot = described_class.new(user)
      ink = snapshot.inks.sole

      values = nil
      assert_queries_match(/SELECT/, count: 0) do
        values = [
          snapshot.tag_names(ink),
          ink.cluster_tags,
          ink.cluster_description,
          ink.brand_description
        ]
      end

      expect(values).to eq([%w[shimmer favourite], %w[blue], "Deep", "A brand"])
    end

    it "returns the same tag names as the ink itself" do
      create(:collected_ink, user:, tags_as_string: "Shimmer, sheen,  ,sheen")

      ink = described_class.new(user).inks.sole

      expect(described_class.new(user).tag_names(ink)).to eq(CollectedInk.find(ink.id).tag_names)
    end

    it "orders tag names by tag id like the old per-ink query" do
      create(:collected_ink, tags_as_string: "second")
      create(:collected_ink, user:, tags_as_string: "first, second")
      snapshot = described_class.new(user)

      expect(snapshot.inks.sole.taggings.map { |tagging| tagging.tag.name }).to eq(%w[first second])
      expect(snapshot.tag_names(snapshot.inks.sole)).to eq(%w[second first])
    end
  end

  describe "#fillable_inks" do
    it "drops swabs and keeps inks without a kind" do
      bottle = create(:collected_ink, user:, kind: "bottle")
      unknown = create(:collected_ink, user:, kind: "")
      create(:collected_ink, user:, kind: "swab")

      expect(described_class.new(user).fillable_inks).to eq([bottle, unknown])
    end
  end

  describe "#inkable_pens" do
    it "drops pens whose nib profile is not inkable and keeps pens without a nib" do
      fountain = create(:collected_pen, user:, nib: "F")
      no_nib = create(:collected_pen, user:, nib: "")
      create(:collected_pen, user:, nib: "rollerball")
      create(:collected_pen, user:, brand: "uni-ball", model: "Signo", nib: "0.38")
      create(:collected_pen, user:, model: "Glass dip pen", nib: "dip")

      snapshot = described_class.new(user)

      expect(snapshot.pens.size).to eq(5)
      expect(snapshot.inkable_pens).to eq([fountain, no_nib])
    end
  end

  describe "query count" do
    def bulk_collection(size)
      now = Time.current
      micro_cluster =
        create(
          :micro_cluster,
          macro_cluster: create(:macro_cluster, brand_cluster: create(:brand_cluster))
        )
      pen_ids =
        CollectedPen
          .insert_all!(
            Array.new(size) do |i|
              { user_id: user.id, brand: "Brand", model: "M#{i}", created_at: now, updated_at: now }
            end,
            returning: :id
          )
          .map { |row| row["id"] }
      ink_ids =
        CollectedInk
          .insert_all!(
            Array.new(size) do |i|
              {
                user_id: user.id,
                brand_name: "Brand",
                ink_name: "I#{i}",
                micro_cluster_id: micro_cluster.id,
                created_at: now,
                updated_at: now
              }
            end,
            returning: :id
          )
          .map { |row| row["id"] }
      tag = Gutentag::Tag.find_or_create_by!(name: "blue")
      Gutentag::Tagging.insert_all!(
        ink_ids.map do |id|
          {
            tag_id: tag.id,
            taggable_id: id,
            taggable_type: "CollectedInk",
            created_at: now,
            updated_at: now
          }
        end
      )
      inking_ids =
        CurrentlyInked
          .insert_all!(
            pen_ids
              .zip(ink_ids)
              .each_with_index
              .map do |(pen_id, ink_id), i|
                {
                  user_id: user.id,
                  collected_pen_id: pen_id,
                  collected_ink_id: ink_id,
                  inked_on: today - 10,
                  archived_on: i.even? ? today - 1 : nil,
                  created_at: now,
                  updated_at: now
                }
              end,
            returning: :id
          )
          .map { |row| row["id"] }
      UsageRecord.insert_all!(
        inking_ids.map do |id|
          { currently_inked_id: id, used_on: today - 2, created_at: now, updated_at: now }
        end
      )
    end

    def load_everything(snapshot)
      [snapshot.pens, snapshot.inks].each { |items| items.each { |item| snapshot.stats_for(item) } }
      snapshot.pair_history
      snapshot.active_inkings.each do |currently_inked|
        currently_inked.pen_name
        currently_inked.ink_name
      end
      snapshot.inks.each do |ink|
        snapshot.tag_names(ink)
        ink.cluster_tags
        ink.brand_description
      end
    end

    def query_count(snapshot)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        load_everything(snapshot)
      end
      count
    end

    it "is the same for 50 and 500 items" do
      bulk_collection(25)
      small = query_count(described_class.new(user))

      bulk_collection(225)
      large = query_count(described_class.new(user))

      expect(described_class.new(user).pens.size).to eq(250)
      expect(small).to eq(11)
      expect(large).to eq(small)
    end

    it "loads usage per inking instead of every usage record" do
      bulk_collection(5)

      assert_queries_match(/FROM "usage_records"/, count: 0) do
        load_everything(described_class.new(user))
      end
      assert_queries_match(/LEFT JOIN usage_records/, count: 1) do
        load_everything(described_class.new(user))
      end
    end
  end

  describe "#stats_for" do
    let(:pen_a) { create(:collected_pen, user:) }
    let(:pen_b) { create(:collected_pen, user:) }
    let(:pen_c) { create(:collected_pen, user:) }
    let(:pen_d) { create(:collected_pen, user:) }
    let(:pen_e) { create(:collected_pen, user:) }
    let(:unused_pen) { create(:collected_pen, user:) }
    let(:ink_a) { create(:collected_ink, user:) }
    let(:ink_b) { create(:collected_ink, user:) }
    let(:ink_c) { create(:collected_ink, user:) }
    let(:ink_d) { create(:collected_ink, user:) }
    let(:ink_e) { create(:collected_ink, user:) }
    let(:unused_ink) { create(:collected_ink, user:) }

    let!(:inkings) do
      [
        ink_it(pen_d, ink_c, inked_on: today - 2, archived_on: today - 1),
        ink_it(
          pen_a,
          ink_a,
          inked_on: today - 100,
          archived_on: today - 90,
          used_on: [today - 95, today - 92]
        ),
        ink_it(pen_a, ink_a, inked_on: today - 30, archived_on: today - 20),
        ink_it(pen_a, ink_b, inked_on: today - 10, used_on: [today - 5, today - 2]),
        ink_it(pen_b, ink_c, inked_on: today - 50, archived_on: today - 40),
        travel_to(1.hour.ago) do
          ink_it(pen_c, ink_d, inked_on: today - 60, archived_on: today - 55)
        end,
        ink_it(pen_c, ink_d, inked_on: today - 80, archived_on: today - 75, used_on: [today - 78]),
        ink_it(pen_d, ink_b, inked_on: today - 5, archived_on: today - 3, used_on: [today - 4]),
        travel_to(3.hours.ago) do
          ink_it(
            pen_e,
            ink_e,
            inked_on: today - 200,
            archived_on: today - 180,
            used_on: [today - 190]
          )
        end,
        travel_to(2.hours.ago) do
          ink_it(
            pen_e,
            ink_e,
            inked_on: today - 150,
            archived_on: today - 130,
            used_on: [today - 140]
          )
        end,
        ink_it(pen_e, ink_e, inked_on: today - 120, archived_on: today - 110)
      ]
    end

    let(:items) do
      [pen_a, pen_b, pen_c, pen_d, pen_e, unused_pen, ink_a, ink_b, ink_c, ink_d, ink_e, unused_ink]
    end

    def legacy_values(item)
      item = item.class.find(item.id)
      [item.usage_count, item.daily_usage_count, item.last_used_on]
    end

    it "equals the old usage_count, daily_usage_count and last_used_on of every item" do
      snapshot = described_class.new(user)

      items.each do |item|
        stats = snapshot.stats_for(item)
        expect([stats.usage_count, stats.daily_usage_count, stats.last_used_on]).to eq(
          legacy_values(item)
        )
      end
    end

    it "has zero counts and no dates for an item that was never inked" do
      stats = described_class.new(user).stats_for(unused_ink)

      expect(stats).to have_attributes(
        usage_count: 0,
        daily_usage_count: 0,
        last_activity_on: nil,
        last_used_on: nil,
        inked?: false
      )
    end

    it "counts an item in an active inking as inked and used today" do
      stats = described_class.new(user).stats_for(ink_b)

      expect(stats.inked?).to be(true)
      expect(stats.last_activity_on).to eq(today)
    end

    it "uses the archived_on of an archived inking as its last activity" do
      expect(described_class.new(user).stats_for(pen_b).last_activity_on).to eq(today - 40)
    end

    it "uses the latest usage when it is newer than the inking's dates" do
      pen = create(:collected_pen, user:)
      ink_it(pen, ink_c, inked_on: today - 180, archived_on: today - 1, used_on: [today - 1])
      ink_it(pen, ink_c, inked_on: today - 300, archived_on: today - 200)

      stats = described_class.new(user).stats_for(pen)

      expect(stats.last_activity_on).to eq(today - 1)
      expect(stats.inked?).to be(false)
    end

    it "counts a pen as inked when an older inking is active and a newer one archived" do
      pen = create(:collected_pen, user:)
      ink_it(pen, ink_c, inked_on: today - 30)
      ink_it(pen, ink_d, inked_on: today - 10, archived_on: today - 5)

      expect(CollectedPen.find(pen.id).inked?).to be(false)
      expect(described_class.new(user).inked?(pen)).to be(true)
    end

    it "counts a pen refilled today as inked" do
      pen = create(:collected_pen, user:)
      ink_it(pen, ink_c, inked_on: today).refill!

      expect(CurrentlyInked.where(collected_pen: pen).pluck(:inked_on)).to eq([today, today])
      expect(described_class.new(user).inked?(pen)).to be(true)
    end

    it "takes the most recently created inking as the newest when inked on the same day" do
      pen = create(:collected_pen, user:)
      ink_it(pen, ink_c, inked_on: today - 30, archived_on: today - 24, used_on: [today - 25])
      ink_it(pen, ink_d, inked_on: today - 30, archived_on: today - 20)

      expect(described_class.new(user).stats_for(pen).last_used_on).to eq(today - 30)
    end
  end

  describe "#pair_history" do
    it "counts the inkings of each pen and ink pair with the last inked_on" do
      pen = create(:collected_pen, user:)
      ink = create(:collected_ink, user:)
      other_ink = create(:collected_ink, user:)
      ink_it(pen, ink, inked_on: today - 50, archived_on: today - 40)
      ink_it(pen, ink, inked_on: today - 20, archived_on: today - 10)
      ink_it(pen, other_ink, inked_on: today - 5)

      expect(described_class.new(user).pair_history).to eq(
        {
          [pen.id, ink.id] => described_class::Pair.new(count: 2, last_inked_on: today - 20),
          [pen.id, other_ink.id] => described_class::Pair.new(count: 1, last_inked_on: today - 5)
        }
      )
    end

    it "ignores other users' inkings" do
      create(:currently_inked)

      expect(described_class.new(user).pair_history).to eq({})
    end
  end

  describe "#active_inkings" do
    it "returns the active currently-inked rows with pen and ink preloaded" do
      pen = create(:collected_pen, user:)
      ink = create(:collected_ink, user:)
      active = ink_it(pen, ink, inked_on: today - 3)
      ink_it(pen, ink, inked_on: today - 30, archived_on: today - 20)
      create(:currently_inked)
      snapshot = described_class.new(user)

      rows = snapshot.active_inkings

      expect(rows).to eq([active])
      assert_queries_match(/SELECT/, count: 0) { rows.each(&:pen_name).each(&:ink_name) }
    end
  end

  describe "#recent_inkings" do
    let(:pen) { create(:collected_pen, user:) }
    let(:ink) { create(:collected_ink, user:) }
    let(:other_pen) { create(:collected_pen, user:) }

    it "returns the last three inkings of each item, newest first, with their notes" do
      dates = [today - 40, today - 30, today - 20, today - 10]
      inkings =
        dates.map do |date|
          ink_it(pen, ink, inked_on: date, archived_on: date + 5, comment: "Note #{date}")
        end
      other = ink_it(other_pen, ink, inked_on: today - 1, comment: "Wet")
      snapshot = described_class.new(user)

      result = nil
      assert_queries_match(/SELECT/, count: 1) { result = snapshot.recent_inkings([pen, ink]) }

      expect(result[pen]).to eq(inkings.last(3).reverse)
      expect(result[ink]).to eq([other, inkings[3], inkings[2]])
      expect(result[ink].map(&:comment)).to eq(["Wet", "Note #{today - 10}", "Note #{today - 20}"])
    end

    it "returns an empty list for an item that was never inked" do
      expect(described_class.new(user).recent_inkings([pen])).to eq({ pen => [] })
    end

    it "makes no query without items" do
      snapshot = described_class.new(user)

      assert_queries_match(/SELECT/, count: 0) { expect(snapshot.recent_inkings([])).to eq({}) }
    end

    it "ignores other users' inkings" do
      create(:currently_inked, collected_pen: create(:collected_pen), comment: "Not mine")

      expect(described_class.new(user).recent_inkings([pen])).to eq({ pen => [] })
    end
  end

  describe "as_of" do
    let(:as_of) { 30.days.ago }
    let(:as_of_date) { as_of.to_date }

    it "uses the as_of date as today" do
      expect(described_class.new(user, as_of:).today).to eq(as_of_date)
      expect(described_class.new(user).today).to eq(today)
    end

    it "keeps items that existed then and were archived later, shown as active" do
      kept = travel_to(as_of - 1.day) { create(:collected_pen, user:) }
      archived_later = travel_to(as_of - 1.day) { create(:collected_pen, user:) }
      archived_later.update!(archived_on: as_of_date + 1)
      archived_that_day = travel_to(as_of - 1.day) { create(:collected_pen, user:) }
      archived_that_day.update!(archived_on: as_of_date)
      create(:collected_pen, user:)

      pens = described_class.new(user, as_of:).pens

      expect(pens).to eq([kept, archived_later])
      expect(pens.map(&:archived?)).to eq([false, false])
      expect(pens).to all(be_readonly)
    end

    it "filters inks by created_at and archived_on" do
      kept = travel_to(as_of - 1.day) { create(:collected_ink, user:) }
      create(:collected_ink, user:)

      expect(described_class.new(user, as_of:).inks).to eq([kept])
    end

    it "filters inkings and usage and treats inkings archived later as active" do
      pen, ink =
        travel_to(as_of - 1.year) { [create(:collected_pen, user:), create(:collected_ink, user:)] }
      active_then =
        travel_to(as_of - 1.day) do
          ink_it(pen, ink, inked_on: as_of_date - 100, archived_on: as_of_date - 90)
          ink_it(
            create(:collected_pen, user:),
            ink,
            inked_on: as_of_date + 3,
            archived_on: as_of_date + 4
          )
          ink_it(pen, ink, inked_on: as_of_date - 20, used_on: [as_of_date - 10, as_of_date - 1])
        end
      create(:usage_record, currently_inked: active_then, used_on: today)
      create(:usage_record, currently_inked: active_then, used_on: as_of_date - 2)
      active_then.update!(archived_on: today)
      ink_it(create(:collected_pen, user:), ink, inked_on: as_of_date - 5, archived_on: today)
      snapshot = described_class.new(user, as_of:)

      expect(snapshot.stats_for(pen)).to have_attributes(
        usage_count: 2,
        daily_usage_count: 2,
        last_activity_on: as_of_date,
        last_used_on: as_of_date - 1,
        inked?: true
      )
      expect(snapshot.stats_for(ink).usage_count).to eq(2)
      expect(snapshot.pair_history.keys).to eq([[pen.id, ink.id]])
      expect(snapshot.active_inkings).to eq([active_then])
      expect(snapshot.active_inkings.map(&:archived_on)).to eq([nil])
      expect(snapshot.active_inkings.map(&:collected_pen)).to eq([pen])
    end

    it "filters the recent inkings" do
      pen = travel_to(as_of - 1.year) { create(:collected_pen, user:) }
      ink = travel_to(as_of - 1.year) { create(:collected_ink, user:) }
      old = travel_to(as_of - 1.day) { ink_it(pen, ink, inked_on: as_of_date - 10) }
      old.update!(archived_on: today)
      ink_it(pen, ink, inked_on: today)

      result = described_class.new(user, as_of:).recent_inkings([pen])

      expect(result[pen]).to eq([old])
      expect(result[pen].map(&:archived_on)).to eq([nil])
    end
  end
end
