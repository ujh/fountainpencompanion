require "rails_helper"

describe "POST /csp-reports" do
  let(:headers) { { "CONTENT_TYPE" => "application/csp-report" } }
  let(:report) do
    {
      "csp-report" => {
        "document-uri" => "https://www.fountainpencompanion.com/",
        "effective-directive" => "script-src-elem",
        "blocked-uri" => "https://evil.example.com/x.js"
      }
    }
  end

  it "records the violation without authentication" do
    post "/csp-reports", params: report.to_json, headers: headers

    expect(response).to have_http_status(:no_content)
    expect(CspReport.sole).to have_attributes(
      directive: "script-src-elem",
      blocked_uri: "https://evil.example.com"
    )
  end

  it "accepts reports with CSRF protection enabled" do
    ActionController::Base.allow_forgery_protection = true
    post "/csp-reports", params: report.to_json, headers: headers

    expect(response).to have_http_status(:no_content)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "rejects invalid JSON" do
    post "/csp-reports", params: "{nope", headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(CspReport.count).to eq(0)
  end

  it "ignores JSON that is not a CSP report" do
    post "/csp-reports", params: [1, 2].to_json, headers: headers

    expect(response).to have_http_status(:no_content)
    expect(CspReport.count).to eq(0)
  end

  it "rejects oversized bodies" do
    post "/csp-reports",
         params: { "csp-report" => { "x" => "y" * 20_000 } }.to_json,
         headers: headers

    expect(response).to have_http_status(:content_too_large)
    expect(CspReport.count).to eq(0)
  end
end
