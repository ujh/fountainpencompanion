require "rails_helper"

describe Admins::PatreonController do
  let(:admin) { create(:user, :admin) }

  def member(member_id:, user_id: nil, email: nil, amount: 500)
    PatreonClient::Member.new(
      member_id: member_id,
      user_id: user_id,
      email: email,
      status: "active_patron",
      amount_cents: amount
    )
  end

  describe "#show" do
    it "requires authentication" do
      get "/admins/patreon"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      around do |example|
        previous = ENV["PATREON_CAMPAIGN_ID"]
        example.run
        ENV["PATREON_CAMPAIGN_ID"] = previous
      end

      it "renders a not-configured notice when env is missing" do
        ENV.delete("PATREON_CAMPAIGN_ID")

        get "/admins/patreon"

        expect(response).to be_successful
        expect(response.body).to include("Patreon is not configured")
      end

      it "splits members into matched and unmatched" do
        ENV["PATREON_CAMPAIGN_ID"] = "campaign-1"
        PatreonCredential.create!(
          access_token: "t",
          refresh_token: "r",
          expires_at: 1.hour.from_now
        )
        create(:user, email: "matched@example.com", name: "Matched User")
        client =
          instance_double(
            PatreonClient,
            members: [
              member(member_id: "m1", email: "matched@example.com"),
              member(member_id: "m2", email: "unknown@example.com")
            ]
          )
        allow(PatreonClient).to receive(:new).and_return(client)

        get "/admins/patreon"

        expect(response).to be_successful
        expect(response.body).to include("matched@example.com")
        expect(response.body).to include("unknown@example.com")
        expect(response.body).to include("Matched User")
      end
    end
  end
end
