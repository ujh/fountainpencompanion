# Emails the admin a digest of confirmed Patreon patrons whose "Add badge"
# benefit still needs to be marked delivered in the Patreon dashboard.
#
# Patreon exposes no API to read or write per-member deliverable status, so we
# track this on our side: a patron is reported once (patreon_badge_reported_at
# stamped), via the nightly sync or immediately on manual connect. The flag is
# reset when a patron is revoked, so a returning patron is reported again.
class PatreonBadgeReporter
  # Accepts users or a relation; reports only those that are confirmed Patreon
  # patrons not yet reported, so callers can pass a broad set safely.
  def self.call(users)
    pending =
      Array(users).select do |user|
        user.patron? && user.patron_source == "patreon" && user.patreon_badge_reported_at.nil?
      end
    return if pending.empty?

    AdminMailer.patreon_badges_to_deliver(pending).deliver_later
    User.where(id: pending.map(&:id)).update_all(patreon_badge_reported_at: Time.current)
  end
end
