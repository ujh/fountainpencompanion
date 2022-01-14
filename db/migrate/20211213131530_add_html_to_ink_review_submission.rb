class AddHtmlToInkReviewSubmission < ActiveRecord::Migration[6.1]
  def change
    add_column :ink_review_submissions, :html, :text
  end
end
