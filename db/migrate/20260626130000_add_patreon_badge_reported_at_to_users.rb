class AddPatreonBadgeReportedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    # When we last emailed the admin to mark this patron's "Add badge" benefit
    # delivered on Patreon. NULL = not yet reported (Patreon has no API to read
    # or write deliverable status, so we track the to-do on our side). Reset to
    # NULL when a patron is revoked so a returning patron is reported again.
    add_column :users, :patreon_badge_reported_at, :datetime
  end
end
