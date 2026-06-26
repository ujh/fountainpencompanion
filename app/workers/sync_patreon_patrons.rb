# Option A: automatically keep the `patron` flag in sync with the Patreon
# campaign's active members. Runs on a schedule (see sidekiq_schedule.yml).
#
# Matching, in priority order:
#   1. patreon_user_id  — set when the user explicitly linked their account
#      (Option B). Authoritative; survives email changes on either side.
#   2. email            — falls back to a case-insensitive email match for
#      users who haven't linked but use the same address on both sides.
#
# Only patrons the sync itself granted (patron_source == "patreon") are ever
# auto-revoked. Admin-pinned ("manual") and legacy/unmanaged (NULL) patrons
# are left untouched, so this can never silently strip a manually granted
# patron who isn't matchable on Patreon.
class SyncPatreonPatrons
  include Sidekiq::Worker

  def perform
    return unless campaign_id.present? && PatreonCredential.configured?

    active_members = client.members(campaign_id).select(&:active?)
    matched_user_ids = grant(User.match_patreon_members(active_members))
    revoke_churned(matched_user_ids)
    report_pending_badges
  end

  private

  def grant(matches)
    matches.filter_map do |member, user|
      next unless user

      attrs = {
        patreon_member_id: member.member_id,
        patreon_user_id: user.patreon_user_id || member.user_id,
        patreon_email: member.email,
        patreon_status: member.status,
        patreon_synced_at: Time.current
      }
      attrs.merge!(patron: true, patron_source: "patreon") unless user.patron_source == "manual"
      user.update!(attrs)
      user.id
    end
  end

  # Anyone we previously granted who is no longer an active member.
  def revoke_churned(matched_user_ids)
    User
      .where(patron_source: "patreon", patron: true)
      .where.not(id: matched_user_ids)
      .find_each do |user|
        user.update!(
          patron: false,
          patreon_status: "former_patron",
          patreon_synced_at: Time.current,
          # so a returning patron is reported to the admin again
          patreon_badge_reported_at: nil
        )
      end
  end

  # Email the admin the confirmed Patreon patrons whose "Add badge" benefit
  # still needs marking delivered (Patreon has no API for this).
  def report_pending_badges
    PatreonBadgeReporter.call(
      User.where(patron: true, patron_source: "patreon", patreon_badge_reported_at: nil)
    )
  end

  def client
    @client ||= PatreonClient.new(PatreonCredential.access_token!)
  end

  def campaign_id
    ENV["PATREON_CAMPAIGN_ID"]
  end
end
