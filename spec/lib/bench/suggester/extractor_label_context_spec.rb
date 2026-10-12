require_relative "bench_helper"

RSpec.describe Bench::Suggester::ExtractorLabelContext do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  def label(text, **context)
    Bench::Suggester::ExtractorLabel.new(
      text:,
      constraints: {
      },
      reviewed: false,
      notes: "",
      **context
    )
  end

  def run(owner, instruction, created_at)
    Bench::Suggester::LoggedRun.new(
      suggester_log(user: owner, instruction:, created_at:, pen_ids: [1], ink_ids: [2])
    )
  end

  it "takes the user and time of the first logged run with the same text" do
    first = run(user, "Only  samples please", Time.zone.parse("2026-04-01 10:00"))
    later = run(other_user, "only samples please", Time.zone.parse("2026-05-01 10:00"))

    labelled = described_class.new(runs: [first, later]).call([label("only samples please")]).sole

    expect(labelled).to have_attributes(user_id: user.id, as_of: first.created_at)
  end

  it "matches a text cut at the widget's limit" do
    long = run(user, "#{"a" * 500}TAIL", Time.zone.parse("2026-04-01 10:00"))

    labelled = described_class.new(runs: [long]).call([label("a" * 500)]).sole

    expect(labelled.user_id).to eq(user.id)
  end

  it "keeps a label's own context and leaves strings without a logged run as they are" do
    logged = run(other_user, "only samples", Time.zone.parse("2026-04-01 10:00"))
    as_of = Time.zone.parse("2026-03-01 10:00")
    labels = [label("only samples", user_id: user.id, as_of:), label("written by hand")]

    labelled = described_class.new(runs: [logged]).call(labels)

    expect(labelled.first).to have_attributes(user_id: user.id, as_of:)
    expect(labelled.last.context?).to be(false)
  end
end
