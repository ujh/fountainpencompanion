require "rails_helper"

describe ErrorReport do
  it "is valid with a reportable and a description" do
    expect(build(:error_report)).to be_valid
  end

  it "requires a description" do
    report = build(:error_report, description: "   ")

    expect(report).not_to be_valid
    expect(report.errors.full_messages).to eq(["Description can't be blank"])
  end

  it "rejects a description longer than 2000 characters" do
    expect(build(:error_report, description: "a" * 2000)).to be_valid
    expect(build(:error_report, description: "a" * 2001)).not_to be_valid
  end

  it "treats a description that is not a string as missing" do
    report = build(:error_report, description: ["Broken"])

    expect(report).not_to be_valid
    expect(report.description).to be_nil
  end

  it "requires a reportable when created" do
    expect(build(:error_report, reportable: nil)).not_to be_valid
  end

  it "rejects a reportable of an unsupported type" do
    expect(build(:error_report, reportable: create(:user))).not_to be_valid
  end

  describe "reportable name" do
    it "stores the name of an ink" do
      ink = create(:macro_cluster, brand_name: "Diamine", line_name: "", ink_name: "Oxblood")

      expect(create(:error_report, reportable: ink).reportable_name).to eq("Diamine Oxblood")
    end

    it "stores the title and ink of a review" do
      ink = create(:macro_cluster, brand_name: "Diamine", line_name: "", ink_name: "Oxblood")
      review = create(:ink_review, macro_cluster: ink, title: "A deep red")

      expect(create(:error_report, reportable: review).reportable_name).to eq(
        "A deep red (review of Diamine Oxblood)"
      )
    end

    it "stores the name of a pen model and a pen variant" do
      pen_model = create(:pens_model, brand: "Pilot", model: "Custom 74")
      pen_variant = create(:pens_model_variant, brand: "Pilot", model: "Custom 74", color: "Blue")

      expect(create(:error_report, reportable: pen_model).reportable_name).to eq("Pilot Custom 74")
      expect(create(:error_report, reportable: pen_variant).reportable_name).to eq(
        "Pilot Custom 74 Blue"
      )
    end

    it "keeps the name and stays updatable after the reportable is deleted" do
      ink = create(:macro_cluster, brand_name: "Diamine", line_name: "", ink_name: "Oxblood")
      report = create(:error_report, reportable: ink)
      ink.destroy

      report.reload.resolve!

      expect(report.reportable).to be_nil
      expect(report.reportable_name).to eq("Diamine Oxblood")
      expect(report).to be_resolved
    end
  end

  describe "#kind" do
    it "names the kind of the reportable" do
      expect(
        [
          create(:ink_review),
          create(:macro_cluster),
          create(:pens_model),
          create(:pens_model_variant)
        ].map { |reportable| build(:error_report, reportable: reportable).kind }
      ).to eq(["Review", "Ink", "Pen model", "Pen variant"])
    end
  end

  describe "status" do
    it "is open until resolved" do
      report = create(:error_report)

      expect(described_class.open).to eq([report])
      report.resolve!

      expect(described_class.open).to be_empty
      expect(described_class.resolved).to eq([report])
    end

    it "keeps the first resolution time when resolved again" do
      report = create(:error_report, resolved_at: 2.days.ago)

      expect { report.resolve! }.not_to change { report.reload.resolved_at }
    end

    it "can be reopened" do
      report = create(:error_report, resolved_at: 1.day.ago)

      report.reopen!

      expect(described_class.open).to eq([report])
    end
  end

  it "is deleted together with the reporter, including its entries" do
    report = create(:error_report)
    create(:error_report_entry, error_report: report)

    expect { report.user.destroy }.to change(described_class, :count).by(-1).and change(
            ErrorReportEntry,
            :count
          ).by(-1)
  end

  it "lists entries in the order they were written" do
    report = create(:error_report)
    later = create(:error_report_entry, error_report: report, created_at: 1.minute.ago)
    earlier = create(:error_report_entry, error_report: report, created_at: 1.hour.ago)

    expect(report.entries).to eq([earlier, later])
  end
end
