# Reconciliation view for the automatic patron sync (Option A). Fetches the
# live list of active Patreon members and shows, for each, whether it matched
# an FPC user. Unmatched members are the ones an admin needs to handle by hand
# (usually a different email on each side, until the user links their account).
class Admins::PatreonController < Admins::BaseController
  def show
    @configured = ENV["PATREON_CAMPAIGN_ID"].present? && PatreonCredential.configured?
    return unless @configured

    members = client.members(ENV["PATREON_CAMPAIGN_ID"]).select(&:active?)
    rows = User.match_patreon_members(members).to_a
    @matched, @unmatched = rows.partition { |(_member, user)| user }
  rescue Faraday::Error => e
    @error = e.message
  end

  private

  def client
    @client ||= PatreonClient.new(PatreonCredential.access_token!)
  end
end
