class AddExtraDataToInkReviewSubmission < ActiveRecord::Migration[8.0]
  def change
    add_column :ink_review_submissions, :extra_data, :jsonb, default: {}
  end
end
