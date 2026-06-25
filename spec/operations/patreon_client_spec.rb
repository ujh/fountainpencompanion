require "rails_helper"

describe PatreonClient do
  let(:campaign_id) { "12345" }

  def member_json(id:, user_id:, email:, status:, amount:)
    {
      id: id,
      type: "member",
      attributes: {
        patron_status: status,
        currently_entitled_amount_cents: amount,
        email: email
      },
      relationships: {
        user: {
          data: {
            id: user_id,
            type: "user"
          }
        }
      }
    }
  end

  describe "#members" do
    it "returns flattened members from a single page" do
      stub_request(
        :get,
        "https://www.patreon.com/api/oauth2/v2/campaigns/#{campaign_id}/members"
      ).with(query: hash_including({})).to_return(
        status: 200,
        headers: {
          "Content-Type" => "application/json"
        },
        body: {
          data: [
            member_json(
              id: "m1",
              user_id: "u1",
              email: "a@example.com",
              status: "active_patron",
              amount: 500
            )
          ],
          meta: {
            pagination: {
              cursors: {
                next: nil
              }
            }
          }
        }.to_json
      )

      members = described_class.new("token").members(campaign_id)

      expect(members.size).to eq(1)
      member = members.first
      expect(member.member_id).to eq("m1")
      expect(member.user_id).to eq("u1")
      expect(member.email).to eq("a@example.com")
      expect(member.status).to eq("active_patron")
      expect(member.amount_cents).to eq(500)
      expect(member).to be_active
    end

    it "follows cursor pagination" do
      base = "https://www.patreon.com/api/oauth2/v2/campaigns/#{campaign_id}/members"
      json_headers = { "Content-Type" => "application/json" }
      page1 = {
        data: [
          member_json(
            id: "m1",
            user_id: "u1",
            email: "a@example.com",
            status: "active_patron",
            amount: 500
          )
        ],
        meta: {
          pagination: {
            cursors: {
              next: "CURSOR2"
            }
          }
        }
      }
      page2 = {
        data: [
          member_json(
            id: "m2",
            user_id: "u2",
            email: "b@example.com",
            status: "former_patron",
            amount: 0
          )
        ],
        meta: {
          pagination: {
            cursors: {
              next: nil
            }
          }
        }
      }

      # WebMock nests bracketed query params, so matching on a flat
      # "page[cursor]" key is unreliable. Return the pages in sequence on the
      # same stub instead.
      stub_request(:get, base).with(query: hash_including({})).to_return(
        { status: 200, headers: json_headers, body: page1.to_json },
        { status: 200, headers: json_headers, body: page2.to_json }
      )

      members = described_class.new("token").members(campaign_id)

      expect(members.map(&:member_id)).to eq(%w[m1 m2])
      expect(members.last).not_to be_active
    end

    it "sends the bearer token" do
      stub =
        stub_request(
          :get,
          "https://www.patreon.com/api/oauth2/v2/campaigns/#{campaign_id}/members"
        ).with(
          query: hash_including({}),
          headers: {
            "Authorization" => "Bearer secret-token"
          }
        ).to_return(
          status: 200,
          headers: {
            "Content-Type" => "application/json"
          },
          body: { data: [], meta: { pagination: { cursors: { next: nil } } } }.to_json
        )

      described_class.new("secret-token").members(campaign_id)

      expect(stub).to have_been_requested
    end
  end

  describe ".refresh_token" do
    around do |example|
      previous = ENV.values_at("PATREON_CLIENT_ID", "PATREON_CLIENT_SECRET")
      ENV["PATREON_CLIENT_ID"] = "client"
      ENV["PATREON_CLIENT_SECRET"] = "secret"
      example.run
      ENV["PATREON_CLIENT_ID"], ENV["PATREON_CLIENT_SECRET"] = previous
    end

    it "exchanges the refresh token for a new pair" do
      stub_request(:post, "https://www.patreon.com/api/oauth2/token").to_return(
        status: 200,
        headers: {
          "Content-Type" => "application/json"
        },
        body: {
          access_token: "new-access",
          refresh_token: "new-refresh",
          expires_in: 2_678_400
        }.to_json
      )

      result = described_class.refresh_token("old-refresh")

      expect(result).to eq(
        access_token: "new-access",
        refresh_token: "new-refresh",
        expires_in: 2_678_400
      )
    end
  end
end
