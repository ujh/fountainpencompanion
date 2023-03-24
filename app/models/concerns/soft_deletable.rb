module SoftDeletable
  extend ActiveSupport::Concern

  included do
    default_scope { where(deleted_at: nil) }

    scope :soft_deleted, -> { unscoped.where.not(deleted_at: nil) }
  end

  def soft_delete!
    touch(:deleted_at)
  end

  def soft_undelete!
    update(deleted_at: nil)
  end
end
