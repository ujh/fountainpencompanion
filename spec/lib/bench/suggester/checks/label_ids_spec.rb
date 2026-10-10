require_relative "../bench_helper"

RSpec.describe Bench::Suggester::Checks::LabelIds do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let(:snapshot) { PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:) }
  let!(:pen) { create(:collected_pen, user:, created_at: as_of - 1.day) }
  let!(:ink) { create(:collected_ink, user:, created_at: as_of - 1.day) }

  def check(label)
    described_class.new(snapshot:, label: Bench::Suggester::Label.from_h(1, label)).call
  end

  it "is empty when every labelled id is in the collection at the time" do
    label = {
      "named_pens" => [pen.id],
      "named_inks" => [ink.id],
      "constraints" => {
        "pen" => {
          "exclude_ids" => [pen.id]
        },
        "ink" => {
          "exclude_ids" => [ink.id]
        }
      }
    }

    expect(check(label)).to eq({})
  end

  it "lists ids that are mistyped, someone else's, added later or archived before" do
    later = create(:collected_pen, user:, created_at: as_of + 1.day)
    someone_elses = create(:collected_pen, created_at: as_of - 1.day)
    archived =
      create(:collected_ink, user:, created_at: as_of - 9.days, archived_on: as_of - 2.days)
    label = {
      "named_pens" => [pen.id, later.id],
      "named_inks" => [0],
      "constraints" => {
        "pen" => {
          "exclude_ids" => [someone_elses.id]
        },
        "ink" => {
          "exclude_ids" => [archived.id, ink.id]
        }
      }
    }

    expect(check(label)).to eq(
      "named_pens" => [later.id],
      "named_inks" => [0],
      "pen.exclude_ids" => [someone_elses.id],
      "ink.exclude_ids" => [archived.id]
    )
  end
end
