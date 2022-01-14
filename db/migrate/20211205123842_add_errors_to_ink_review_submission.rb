class AddErrorsToInkReviewSubmission < ActiveRecord::Migration[6.1]
  def change
    add_column :ink_review_submissions, :unfurling_errors, :text
  end
end
