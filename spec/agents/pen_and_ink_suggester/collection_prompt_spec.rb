require "rails_helper"
require "active_record/testing/query_assertions"

RSpec.describe PenAndInkSuggester do
  include RSpec::Rails::MinitestAssertionAdapter
  include ActiveSupport::Testing::Assertions
  include ActiveRecord::Assertions::QueryAssertions

  let(:legacy_suggester_class) do
    Class.new(PenAndInkSuggester) do
      private

      def additional_premium_prompt
        currently_inked = user.currently_inkeds.active.order(:id).to_csv
        <<~MESSAGE
          Below is the list of currently inked pens in my collection:
          #{currently_inked}

          When picking a new pen and ink combination, take these into account and
          prefer combinations that do not overlap with the currently inked pens
          and inks. Prefer a variety of ink colors and nib sizes.
        MESSAGE
      end

      def average_pen_usage
        average_usage = (pens.sum(&:usage_count) / pens.size.to_f).round(2)
        average_daily_usage = (pens.sum(&:daily_usage_count) / pens.size.to_f).round(2)
        average_last_used_ago =
          pens.sum do |pen|
            last_used_on = pen.last_used_on || Date.today.advance(years: -1)
            (Date.today - last_used_on).to_i
          end / pens.size.to_f
        average_last_used_ago = time_ago_in_words(Date.today.advance(days: -average_last_used_ago))
        stats = { average_usage:, average_daily_usage:, average_last_used_ago: }
        "Pens have the following average statistics:\n#{stats.to_json}"
      end

      def average_ink_usage
        average_usage = (inks.sum(&:usage_count) / inks.size.to_f).round(2)
        average_daily_usage = (inks.sum(&:daily_usage_count) / inks.size.to_f).round(2)
        average_last_used_ago =
          inks.sum do |ink|
            last_used_on = ink.last_used_on || Date.today.advance(years: -1)
            (Date.today - last_used_on).to_i
          end / inks.size.to_f
        average_last_used_ago = time_ago_in_words(Date.today.advance(days: -average_last_used_ago))
        stats = { average_usage:, average_daily_usage:, average_last_used_ago: }
        "Inks have the following average statistics:\n#{stats.to_json}"
      end

      def pen_data
        CSV.generate do |csv|
          csv << ["pen id", "fountain pen name", "last usage", "usage count", "daily usage count"]
          pens
            .shuffle
            .take(limit)
            .each do |pen|
              last_usage = (pen.last_used_on ? time_ago_in_words(pen.last_used_on) : "never")
              csv << [pen.id, pen.name.inspect, last_usage, pen.usage_count, pen.daily_usage_count]
            end
        end
      end

      def ink_data
        CSV.generate do |csv|
          csv << [
            "ink id",
            "ink name",
            "type",
            "last usage",
            "usage count",
            "daily usage count",
            "tags",
            "description"
          ]

          inks
            .shuffle
            .take(limit)
            .each do |ink|
              last_usage = (ink.last_used_on ? time_ago_in_words(ink.last_used_on) : "never")
              csv << [
                ink.id,
                ink.name.inspect,
                ink.kind,
                last_usage,
                ink.usage_count,
                ink.daily_usage_count,
                (ink.tag_names + ink.cluster_tags).uniq.join(","),
                ink.cluster_description || ""
              ]
            end
        end
      end

      def pens
        @pens ||= user.collected_pens.active.order(:id).reject { |pen| pen.inked? }
      end

      def inks
        @inks ||= user.collected_inks.active.order(:id).to_a
      end
    end
  end

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

  def build_collection
    macro_cluster =
      create(:macro_cluster, tags: %w[blue sheen], description: "A deep \"blue\", with sheen")
    micro_cluster = create(:micro_cluster, macro_cluster:)
    pens = [
      create(:collected_pen, user:, brand: "Pilot", model: "Custom 74", nib: "M"),
      create(:collected_pen, user:, brand: 'Test "Brand"', model: "Safari", nib: ""),
      create(:collected_pen, user:, brand: "Sailor", model: "Pro Gear", nib: "21k F"),
      create(:collected_pen, user:, brand: "uni-ball", model: "Signo", nib: "0.38"),
      create(:collected_pen, user:, brand: "TWSBI", model: "Eco", nib: "1.1 stub")
    ]
    inks = [
      create(:collected_ink, user:, micro_cluster:, tags_as_string: "favourite, blue"),
      create(:collected_ink, user:, kind: "cartridge", line_name: "Iroshizuku"),
      create(:collected_ink, user:, kind: "swab", micro_cluster:),
      create(:collected_ink, user:, kind: ""),
      create(:collected_ink, user:, kind: "sample")
    ]
    create(:collected_pen, user:, archived_on: today)
    create(:collected_ink, user:, archived_on: today)
    create(:currently_inked)

    ink_it(
      pens[0],
      inks[0],
      inked_on: today - 300,
      archived_on: today - 250,
      used_on: [today - 290, today - 260]
    )
    ink_it(pens[0], inks[0], inked_on: today - 100, archived_on: today - 80)
    ink_it(pens[1], inks[1], inked_on: today - 40, archived_on: today - 20, used_on: [today - 30])
    ink_it(pens[2], inks[1], inked_on: today - 12, used_on: [today - 3, today - 1], comment: "Wet")
    ink_it(pens[4], inks[3], inked_on: today - 400, archived_on: today - 380)
    refilled_pen = create(:collected_pen, user:, brand: "Lamy", model: "2000")
    ink_it(
      refilled_pen,
      inks[4],
      inked_on: today - 60,
      archived_on: today - 50,
      used_on: [today - 55]
    )
    ink_it(refilled_pen, inks[4], inked_on: today - 10)
    archived_pen = create(:collected_pen, user:)
    ink_it(archived_pen, inks[0], inked_on: today - 9, comment: "Old pen")
    archived_pen.update!(archived_on: today)
  end

  def prompt(suggester_class, user)
    srand(42)
    suggester_class.new(user, nil).send(:user_prompt)
  end

  it "builds the same prompt as the old per-item model methods" do
    build_collection

    new_prompt = prompt(described_class, user)

    expect(new_prompt).to eq(prompt(legacy_suggester_class, user))
    expect(new_prompt).to include("Custom 74", "Eco", "Iroshizuku", "favourite,blue,sheen")
  end

  it "builds the same premium prompt with the currently inked pens" do
    user.update!(patron: true)
    build_collection

    new_prompt = prompt(described_class, user)

    expect(new_prompt).to eq(prompt(legacy_suggester_class, user))
    expect(new_prompt).to include("currently inked pens", "Wet", "Old pen")
  end

  it "builds the same prompt when nothing was ever inked" do
    create(:collected_pen, user:)
    create(:collected_ink, user:)

    expect(prompt(described_class, user)).to eq(prompt(legacy_suggester_class, user))
  end

  it "offers only uninked pens and checks suggestions against them" do
    build_collection
    suggester = described_class.new(user, nil)

    pens = suggester.send(:pens)

    expect(pens.map(&:model)).to eq(["Custom 74", "Safari", "Signo", "Eco"])
    expect(suggester.send(:legacy_record_suggestion_tool).pens).to eq(pens)
  end

  def prompt_queries(user)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      described_class.new(user, nil).send(:user_prompt)
    end
    count
  end

  it "makes the same number of queries for a small and a large collection" do
    user.update!(patron: true)
    build_collection
    small = prompt_queries(user)

    3.times { build_collection }
    large = prompt_queries(user)

    expect(large).to eq(small)
  end
end
