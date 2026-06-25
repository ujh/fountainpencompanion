class AddPatreonFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :patreon_user_id, :string
    add_column :users, :patreon_member_id, :string
    add_column :users, :patreon_email, :string
    add_column :users, :patreon_status, :string
    # NULL = legacy/unmanaged (never auto-revoked), "manual" = admin pinned
    # (never auto-managed), "patreon" = granted by the sync (auto-revoked on
    # churn). Defaults to NULL so existing patrons are never touched by the
    # sync until they actively match a Patreon membership.
    add_column :users, :patron_source, :string
    add_column :users, :patreon_synced_at, :datetime
  end
end
