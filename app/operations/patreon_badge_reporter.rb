# Emails the admin a digest of confirmed Patreon patrons whose "Add badge"
# benefit still needs to be marked delivered in the Patreon dashboard.
#
# Patreon exposes no API to read or write per-member deliverable status, so we
# track this on our side: a patron is reported once (patreon_badge_reported_at
# stamped), via the nightly sync or immediately on manual connect. The flag is
# reset when a patron is revoked, so a returning patron is reported again.
class PatreonBadgeReporter
  attr_accessor :users

  # Accepts users or a relation; reports only those that are confirmed Patreon
  # patrons not yet reported, so callers can pass a broad set safely.
  def initialize(users)
    self.users = users
  end

  def perform
    pending =
      Array(users).select do |user|
        user.patron? && user.patron_source == "patreon" && user.patreon_badge_reported_at.nil?
      end
    return if pending.empty?

    AdminMailer.patreon_badges_to_deliver(pending).deliver_later
    # Stamped on enqueue, so "report once" is really "at most once": if the
    # mail job exhausts its retries the digest is lost and these patrons won't
    # resurface (only a Patreon revoke resets the flag). Acceptable for an
    # admin digest — a dropped email is low-stakes and the /admins/patreon
    # reconciliation page is a backstop.
    User.where(id: pending.map(&:id)).update_all(patreon_badge_reported_at: Time.current)
  end
end
