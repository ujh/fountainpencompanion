class AddAgentApprovedFlagtoInkReview < ActiveRecord::Migration[8.0]
  def change
    add_column :ink_reviews, :agent_approved, :boolean, default: false
  end
end
