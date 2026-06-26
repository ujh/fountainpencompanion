require "rails_helper"

describe PatreonConnectionsController do
  let(:user) { create(:user) }

  def identity_double(email:, memberships: [])
    PatreonClient::Identity.new(patreon_user_id: "pu-1", email: email, memberships: memberships)
  end

  def membership(campaign_id:, status: "active_patron", amount: 500)
    PatreonClient::Membership.new(campaign_id: campaign_id, status: status, amount_cents: amount)
  end

  around do |example|
    keys = %w[PATREON_CLIENT_ID PATREON_CLIENT_SECRET PATREON_CAMPAIGN_ID]
    previous = ENV.values_at(*keys)
    ENV["PATREON_CLIENT_ID"] = "cid"
    ENV["PATREON_CLIENT_SECRET"] = "secret"
    ENV["PATREON_CAMPAIGN_ID"] = "camp-1"
    example.run
    keys.each_with_index { |k, i| ENV[k] = previous[i] }
  end

  describe "#connect" do
    it "requires authentication" do
      get patreon_connect_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to the Patreon authorize URL" do
      sign_in(user)
      get patreon_connect_path
      expect(response.location).to match(%r{patreon\.com/oauth2/authorize})
    end
  end

  describe "#callback" do
    before { sign_in(user) }

    # connect stores the CSRF state in the session and redirects with it in the
    # URL; read it back so the callback passes state validation.
    def connect_and_state
      get patreon_connect_path
      Rack::Utils.parse_query(URI(response.location).query)["state"]
    end

    it "links the account and grants patron for an active campaign membership" do
      state = connect_and_state
      allow(PatreonClient).to receive(:exchange_code).and_return("access_token" => "tok")
      allow(PatreonClient).to receive(:new).with("tok").and_return(
        instance_double(
          PatreonClient,
          identity:
            identity_double(
              email: "other@example.com",
              memberships: [membership(campaign_id: "camp-1")]
            )
        )
      )

      get patreon_callback_path(code: "c", state: state)

      user.reload
      expect(user.patreon_user_id).to eq("pu-1")
      expect(user.patreon_email).to eq("other@example.com")
      expect(user.patron).to be(true)
      expect(user.patron_source).to eq("patreon")
      expect(response).to redirect_to(account_path)
    end

    it "links but does not grant when there is no active membership" do
      state = connect_and_state
      allow(PatreonClient).to receive(:exchange_code).and_return("access_token" => "tok")
      allow(PatreonClient).to receive(:new).and_return(
        instance_double(PatreonClient, identity: identity_double(email: "other@example.com"))
      )

      get patreon_callback_path(code: "c", state: state)

      user.reload
      expect(user.patreon_user_id).to eq("pu-1")
      expect(user.patron).to be(false)
    end

    it "grants for the temporary test email even without a membership" do
      state = connect_and_state
      allow(PatreonClient).to receive(:exchange_code).and_return("access_token" => "tok")
      allow(PatreonClient).to receive(:new).and_return(
        instance_double(PatreonClient, identity: identity_double(email: "urban@bettong.net"))
      )

      get patreon_callback_path(code: "c", state: state)

      expect(user.reload.patron).to be(true)
    end

    it "does not downgrade an admin-pinned (manual) patron's source" do
      user.update!(patron: true, patron_source: "manual")
      state = connect_and_state
      allow(PatreonClient).to receive(:exchange_code).and_return("access_token" => "tok")
      allow(PatreonClient).to receive(:new).and_return(
        instance_double(
          PatreonClient,
          identity:
            identity_double(
              email: "other@example.com",
              memberships: [membership(campaign_id: "camp-1")]
            )
        )
      )

      get patreon_callback_path(code: "c", state: state)

      user.reload
      expect(user.patreon_user_id).to eq("pu-1") # link still recorded
      expect(user.patron).to be(true)
      expect(user.patron_source).to eq("manual") # not overwritten
    end

    it "rejects and alerts when the Patreon API errors" do
      state = connect_and_state
      allow(PatreonClient).to receive(:exchange_code).and_raise(
        Faraday::ConnectionFailed.new("boom")
      )

      get patreon_callback_path(code: "c", state: state)

      expect(response).to redirect_to(account_path)
      expect(flash[:alert]).to be_present
      expect(user.reload.patreon_user_id).to be_nil
    end

    it "rejects and alerts when Patreon returns a non-JSON body" do
      state = connect_and_state
      allow(PatreonClient).to receive(:exchange_code).and_raise(
        JSON::ParserError.new("unexpected token")
      )

      get patreon_callback_path(code: "c", state: state)

      expect(response).to redirect_to(account_path)
      expect(flash[:alert]).to be_present
      expect(user.reload.patreon_user_id).to be_nil
    end

    it "rejects a mismatched state without exchanging the code" do
      connect_and_state
      expect(PatreonClient).not_to receive(:exchange_code)

      get patreon_callback_path(code: "c", state: "wrong")

      expect(response).to redirect_to(account_path)
      expect(flash[:alert]).to be_present
    end

    it "rejects when Patreon returns an error param" do
      expect(PatreonClient).not_to receive(:exchange_code)

      get patreon_callback_path(error: "access_denied")

      expect(flash[:alert]).to be_present
    end

    it "reports when the Patreon account is already linked to another user" do
      create(:user, patreon_user_id: "pu-1")
      state = connect_and_state
      allow(PatreonClient).to receive(:exchange_code).and_return("access_token" => "tok")
      allow(PatreonClient).to receive(:new).and_return(
        instance_double(PatreonClient, identity: identity_double(email: "other@example.com"))
      )

      get patreon_callback_path(code: "c", state: state)

      expect(flash[:alert]).to match(/already linked/)
    end
  end

  describe "#destroy" do
    before { sign_in(user) }

    it "clears the link" do
      user.update!(patreon_user_id: "pu-1", patreon_email: "x@example.com")

      delete patreon_disconnect_path

      user.reload
      expect(user.patreon_user_id).to be_nil
      expect(user.patreon_email).to be_nil
      expect(response).to redirect_to(account_path)
    end
  end
end
