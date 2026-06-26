# Thin Faraday wrapper around the Patreon v2 API. Used to read the campaign
# member list for the automatic patron sync (Option A), to refresh creator
# tokens, and to drive the per-user "Connect Patreon" OAuth flow (Option B).
#
# The Patreon host is fixed and trusted, so (unlike SafeHttp) there is no SSRF
# concern here — we talk to exactly one known endpoint with a bearer token.
class PatreonClient
  API_BASE = "https://www.patreon.com/api/oauth2/v2".freeze
  TOKEN_URL = "https://www.patreon.com/api/oauth2/token".freeze
  AUTHORIZE_URL = "https://www.patreon.com/oauth2/authorize".freeze
  OAUTH_SCOPE = "identity identity[email] identity.memberships".freeze
  PAGE_SIZE = 1000
  MEMBER_FIELDS = "patron_status,currently_entitled_amount_cents,email".freeze
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  # One Patreon campaign member, flattened to the fields the sync cares about.
  Member =
    Struct.new(:member_id, :user_id, :email, :status, :amount_cents, keyword_init: true) do
      def active?
        status == "active_patron" && amount_cents.to_i.positive?
      end
    end

  # The authenticated user's own membership on a campaign (from the identity
  # endpoint during the OAuth flow).
  Membership =
    Struct.new(:campaign_id, :status, :amount_cents, keyword_init: true) do
      def active?
        status == "active_patron" && amount_cents.to_i.positive?
      end
    end

  # The authenticated user as returned by the identity endpoint.
  Identity = Struct.new(:patreon_user_id, :email, :memberships, keyword_init: true)

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

  # The authenticated user (uses this instance's per-user access token) plus
  # their memberships, so the OAuth callback can decide if they are an active
  # patron of our campaign.
  def identity
    body =
      JSON.parse(
        connection
          .get("identity") do |req|
            req.params["include"] = "memberships.campaign"
            req.params["fields[user]"] = "email"
            req.params["fields[member]"] = "patron_status,currently_entitled_amount_cents"
          end
          .body
      )
    parse_identity(body)
  end

  # Builds the URL we redirect a user to so they can authorize the connection.
  def self.authorize_url(redirect_uri:, state:)
    query =
      URI.encode_www_form(
        response_type: "code",
        client_id: ENV.fetch("PATREON_CLIENT_ID"),
        redirect_uri: redirect_uri,
        scope: OAUTH_SCOPE,
        state: state
      )
    "#{AUTHORIZE_URL}?#{query}"
  end

  # Exchanges the authorization code from the OAuth callback for an access
  # token tied to that user.
  def self.exchange_code(code, redirect_uri:)
    token_post(
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: ENV.fetch("PATREON_CLIENT_ID"),
      client_secret: ENV.fetch("PATREON_CLIENT_SECRET")
    )
  end

  # Exchanges a (rotating) refresh token for a fresh access/refresh token pair.
  def self.refresh_token(refresh_token)
    data =
      token_post(
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: ENV.fetch("PATREON_CLIENT_ID"),
        client_secret: ENV.fetch("PATREON_CLIENT_SECRET")
      )
    {
      access_token: data["access_token"],
      refresh_token: data["refresh_token"],
      expires_in: data["expires_in"]
    }
  end

  def self.token_post(params)
    response =
      Faraday
        .new do |f|
          f.options.open_timeout = OPEN_TIMEOUT
          f.options.timeout = READ_TIMEOUT
          f.response :raise_error
        end
        .post(
          TOKEN_URL,
          URI.encode_www_form(params),
          "Content-Type" => "application/x-www-form-urlencoded"
        )
    JSON.parse(response.body)
  end
  private_class_method :token_post

  private

  def connection
    @connection ||=
      Faraday.new(url: API_BASE) do |f|
        f.headers["Authorization"] = "Bearer #{access_token}"
        f.options.open_timeout = OPEN_TIMEOUT
        f.options.timeout = READ_TIMEOUT
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

  def parse_identity(body)
    data = body["data"] || {}
    memberships =
      Array(body["included"])
        .select { |resource| resource["type"] == "member" }
        .map do |member|
          attributes = member["attributes"] || {}
          Membership.new(
            campaign_id: member.dig("relationships", "campaign", "data", "id"),
            status: attributes["patron_status"],
            amount_cents: attributes["currently_entitled_amount_cents"]
          )
        end
    Identity.new(
      patreon_user_id: data["id"],
      email: data.dig("attributes", "email"),
      memberships: memberships
    )
  end
end
