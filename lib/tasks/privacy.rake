namespace :privacy do
  desc "Replace submitter emails in stored ReviewApprover transcripts with \"user\""
  task scrub_review_approver_emails: :environment do
    puts "Scrubbed #{ScrubReviewApproverEmails.new.perform} transcripts"
  end
end
