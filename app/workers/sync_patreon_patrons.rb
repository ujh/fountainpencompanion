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
    matched_user_ids = grant(active_members)
    revoke_churned(matched_user_ids)
  end

  private

  def grant(active_members)
    active_members.filter_map do |member|
      user = match_user(member)
      next unless user

      user.update!(
        patreon_member_id: member.member_id,
        patreon_user_id: user.patreon_user_id || member.user_id,
        patreon_email: member.email,
        patreon_status: member.status,
        patreon_synced_at: Time.current
      )
      user.update!(patron: true, patron_source: "patreon") unless user.patron_source == "manual"
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
          patreon_synced_at: Time.current
        )
      end
  end

  def match_user(member)
    by_linked_id(member) || by_email(member)
  end

  def by_linked_id(member)
    return if member.user_id.blank?

    User.find_by(patreon_user_id: member.user_id)
  end

  def by_email(member)
    return if member.email.blank?

    User.where("lower(email) = ?", member.email.downcase).first
  end

  def client
    @client ||= PatreonClient.new(PatreonCredential.access_token!)
  end

  def campaign_id
    ENV["PATREON_CAMPAIGN_ID"]
  end
end
