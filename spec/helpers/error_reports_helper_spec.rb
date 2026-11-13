require "rails_helper"

describe ErrorReportsHelper do
  def page_url(reportable)
    helper.error_report_page_url(create(:error_report, reportable: reportable))
  end

  it "links a review report to the ink page of the review" do
    review = create(:ink_review)

    expect(page_url(review)).to eq(ink_url(review.macro_cluster))
  end

  it "links an ink report to the ink page" do
    ink = create(:macro_cluster)

    expect(page_url(ink)).to eq(ink_url(ink))
  end

  it "links a pen model report to the pen model page" do
    pen_model = create(:pens_model)

    expect(page_url(pen_model)).to eq(pen_model_url(pen_model))
  end

  it "links a pen variant report to the pen variant page" do
    pen_variant = create(:pens_model_variant)

    expect(page_url(pen_variant)).to eq(pen_variant_url(pen_variant))
  end

  it "returns nil when the reported item no longer exists" do
    ink = create(:macro_cluster)
    report = create(:error_report, reportable: ink)
    ink.destroy

    expect(helper.error_report_page_url(report.reload)).to be_nil
  end
end
