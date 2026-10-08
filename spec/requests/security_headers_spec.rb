require "rails_helper"

describe "security headers" do
  def policy
    response.headers["Content-Security-Policy-Report-Only"]
  end

  it "sends a report-only Content Security Policy" do
    get "/"

    expect(response.headers["Content-Security-Policy"]).to be_nil
    expect(policy).to include("default-src 'self'", "object-src 'none'", "report-uri /csp-reports")
  end

  it "allows images over http for review thumbnails that link to http URLs" do
    get "/"

    expect(policy).to include("img-src 'self' data: https: http:")
  end

  it "allows data: fonts" do
    get "/"

    expect(policy).to include("font-src 'self' data:")
  end

  it "allows inline scripts only through a per-request nonce" do
    get "/"
    first_nonce = policy[/'nonce-([^']+)'/, 1]
    expect(response.body).to include(%(nonce="#{first_nonce}"))

    get "/"
    expect(policy[/'nonce-([^']+)'/, 1]).not_to eq(first_nonce)
  end

  describe "inline scripts" do
    let(:user) { create(:user, time_zone: nil) }

    def expect_only_nonced_inline_scripts
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to match(/\son[a-z]+=/)
      expect(response.body.scan(/<script(?![^>]*\bsrc=)[^>]*>/)).to all(include("nonce="))
    end

    it "are all nonced on public pages" do
      %w[/ /users/sign_up /users/sign_in].each do |path|
        get path
        expect_only_nonced_inline_scripts
      end
    end

    it "are all nonced on signed-in pages" do
      sign_in(user)

      %w[/dashboard /account /collected_inks /collected_pens /currently_inked].each do |path|
        get path
        expect_only_nonced_inline_scripts
      end
    end

    it "are all nonced on the API token page that shows a new token" do
      sign_in(user)
      post "/authentication_tokens", params: { authentication_token: { name: "Script" } }
      follow_redirect!

      expect_only_nonced_inline_scripts
      expect(response.body).to include('data-copy-target="new-token-value"')
    end

    it "are all nonced on the ink name editing page" do
      sign_in(user)
      brand = create(:brand_cluster)
      ink = create(:macro_cluster, brand_cluster: brand)

      get "/brands/#{brand.id}/inks/#{ink.id}/edit_name"

      expect_only_nonced_inline_scripts
    end
  end

  describe "time zone detection" do
    it "asks the browser for the time zone when the user has none" do
      sign_in(create(:user, time_zone: nil))

      get "/dashboard"

      expect(response.body).to include("data-detect-time-zone")
    end

    it "does not ask when the user already has a time zone" do
      sign_in(create(:user, time_zone: "Europe/Berlin"))

      get "/dashboard"

      expect(response.body).not_to include("data-detect-time-zone")
    end
  end

  it "denies powerful browser features" do
    get "/"

    expect(response.headers["Permissions-Policy"]).to eq(
      "camera=(), microphone=(), geolocation=(), payment=(), usb=()"
    )
  end
end
