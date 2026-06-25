# Reconciliation view for the automatic patron sync (Option A). Fetches the
# live list of active Patreon members and shows, for each, whether it matched
# an FPC user. Unmatched members are the ones an admin needs to handle by hand
# (usually a different email on each side, until the user links their account).
class Admins::PatreonController < Admins::BaseController
  def show
    @configured = ENV["PATREON_CAMPAIGN_ID"].present? && PatreonCredential.configured?
    return unless @configured

    members = client.members(ENV["PATREON_CAMPAIGN_ID"]).select(&:active?)
    rows = members.map { |member| [member, match_user(member)] }
    @matched, @unmatched = rows.partition { |(_member, user)| user }
  rescue Faraday::Error => e
    @error = e.message
  end

  private

  def match_user(member)
    if member.user_id.present?
      user = User.find_by(patreon_user_id: member.user_id)
      return user if user
    end
    return if member.email.blank?

    User.where("lower(email) = ?", member.email.downcase).first
  end

  def client
    @client ||= PatreonClient.new(PatreonCredential.access_token!)
  end
end
