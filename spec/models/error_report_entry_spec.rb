require "rails_helper"

describe ErrorReportEntry do
  it "is a note or a reply" do
    expect(build(:error_report_entry, kind: "note")).to be_valid
    expect(build(:error_report_entry, kind: "reply")).to be_valid
    expect(build(:error_report_entry, kind: "other")).not_to be_valid
  end

  it "tells notes and replies apart" do
    expect(build(:error_report_entry, kind: "note")).to have_attributes(note?: true, reply?: false)
    expect(build(:error_report_entry, kind: "reply")).to have_attributes(note?: false, reply?: true)
  end

  it "requires a body" do
    expect(build(:error_report_entry, body: " ")).not_to be_valid
  end

  it "rejects a body longer than 10000 characters" do
    expect(build(:error_report_entry, body: "a" * 10_000)).to be_valid
    expect(build(:error_report_entry, body: "a" * 10_001)).not_to be_valid
  end
end
