require "rails_helper"

describe "Error reporting on the pen pages" do
  let(:brand) { create(:pens_brand) }
  let(:pen_model) { create(:pens_model, pen_brand: brand) }
  let(:pen_variant) do
    create(
      :pens_model_variant,
      model_micro_cluster: create(:pens_model_micro_cluster, model: pen_model)
    )
  end
  let(:pages) do
    {
      pen_model_report_path(pen_model) => pen_brand_pen_model_path(brand, pen_model),
      pen_variant_report_path(pen_variant) =>
        pen_brand_pen_model_pen_variant_path(brand, pen_model, pen_variant)
    }
  end

  def report_section(path)
    get path
    Nokogiri.HTML(response.body).at_css(".fpc-ink-details__error-reporting")
  end

  it "asks signed out users to sign in to report an error" do
    pages.each_value do |page_path|
      section = report_section(page_path)

      expect(section.css(".fpc-report-button")).to be_empty
      expect(section.at_css("a[href='/users/sign_in']").text).to eq("Sign in to report an error")
    end
  end

  it "offers signed in users a report button for the page" do
    sign_in(create(:user))

    pages.each do |report_path, page_path|
      button = report_section(page_path).at_css(".fpc-report-button")

      expect(button["data-url"]).to eq(report_path)
      expect(button["data-label"]).to eq("Report an error")
    end
  end
end
