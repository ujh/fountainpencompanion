# Stores the creator-level OAuth tokens used to read the campaign's member
# list (Option A — automatic patron sync by matching email/Patreon user id).
#
# Patreon access tokens are short-lived and refresh tokens rotate on every
# refresh, so the tokens cannot live in ENV — they must be persisted and
# updated in place. There is only ever one row.
#
# Seed it once (values from the Patreon developer portal) via the console:
#
#   PatreonCredential.create!(
#     access_token: "...",
#     refresh_token: "...",
#     expires_at: 1.month.from_now
#   )
class PatreonCredential < ApplicationRecord
  # Refresh a little before the token actually expires to avoid racing the
  # boundary mid-request.
  EXPIRY_LEEWAY = 5.minutes

  def self.access_token!
    cred = current
    cred.refresh! if cred.expired?
    cred.access_token
  end

  def self.current
    first || raise("No Patreon credential configured")
  end

  def self.configured?
    exists?
  end

  def expired?
    expires_at.nil? || expires_at <= EXPIRY_LEEWAY.from_now
  end

  def refresh!
    data = PatreonClient.refresh_token(refresh_token)
    update!(
      access_token: data[:access_token],
      refresh_token: data[:refresh_token],
      expires_at: data[:expires_in].to_i.seconds.from_now
    )
  end
end
