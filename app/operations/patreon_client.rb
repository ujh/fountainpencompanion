# Thin Faraday wrapper around the Patreon v2 API. Used to read the campaign
# member list for the automatic patron sync and to refresh creator tokens.
#
# The Patreon host is fixed and trusted, so (unlike SafeHttp) there is no SSRF
# concern here — we talk to exactly one known endpoint with a bearer token.
class PatreonClient
  API_BASE = "https://www.patreon.com/api/oauth2/v2".freeze
  TOKEN_URL = "https://www.patreon.com/api/oauth2/token".freeze
  PAGE_SIZE = 1000
  MEMBER_FIELDS = "patron_status,currently_entitled_amount_cents,email".freeze

  # One Patreon member, flattened to the fields the sync cares about.
  Member =
    Struct.new(:member_id, :user_id, :email, :status, :amount_cents, keyword_init: true) do
      def active?
        status == "active_patron" && amount_cents.to_i.positive?
      end
    end

  attr_accessor :access_token

  def initialize(access_token)
    self.access_token = access_token
  end

  # Returns every member of the campaign, following cursor pagination.
  def members(campaign_id)
    results = []
    seen_cursors = []
    cursor = nil
    loop do
      body = fetch_members_page(campaign_id, cursor)
      results.concat(parse_members(body))
      cursor = body.dig("meta", "pagination", "cursors", "next")
      # Stop on the end of the list, and guard against a misbehaving API that
      # keeps handing back a cursor we've already followed (which would loop
      # forever).
      break if cursor.blank? || seen_cursors.include?(cursor)

      seen_cursors << cursor
    end
    results
  end

  # Exchanges a (rotating) refresh token for a fresh access/refresh token pair.
  def self.refresh_token(refresh_token)
    response =
      Faraday
        .new { |f| f.response :raise_error }
        .post(
          TOKEN_URL,
          URI.encode_www_form(
            grant_type: "refresh_token",
            refresh_token: refresh_token,
            client_id: ENV.fetch("PATREON_CLIENT_ID"),
            client_secret: ENV.fetch("PATREON_CLIENT_SECRET")
          ),
          "Content-Type" => "application/x-www-form-urlencoded"
        )
    data = JSON.parse(response.body)
    {
      access_token: data["access_token"],
      refresh_token: data["refresh_token"],
      expires_in: data["expires_in"]
    }
  end

  private

  def connection
    @connection ||=
      Faraday.new(url: API_BASE) do |f|
        f.headers["Authorization"] = "Bearer #{access_token}"
        f.response :raise_error
      end
  end

  def fetch_members_page(campaign_id, cursor)
    response =
      connection.get("campaigns/#{campaign_id}/members") do |req|
        req.params["include"] = "user"
        req.params["fields[member]"] = MEMBER_FIELDS
        req.params["page[count]"] = PAGE_SIZE
        req.params["page[cursor]"] = cursor if cursor
      end
    JSON.parse(response.body)
  end

  def parse_members(body)
    Array(body["data"]).map do |member|
      attributes = member["attributes"] || {}
      Member.new(
        member_id: member["id"],
        user_id: member.dig("relationships", "user", "data", "id"),
        email: attributes["email"],
        status: attributes["patron_status"],
        amount_cents: attributes["currently_entitled_amount_cents"]
      )
    end
  end
end
