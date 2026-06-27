require "rails_helper"

describe EnqueueInkReviewChecks do
  it "enqueues a CheckInkReview job for each due review" do
    due = create(:ink_review, approved_at: Time.now, next_check_at: 1.hour.ago)
    expect { subject.perform }.to change(CheckInkReview.jobs, :length).by(1)
    expect(CheckInkReview.jobs.first["args"]).to eq([due.id])
  end

  it "does not enqueue jobs for reviews not yet due" do
    create(:ink_review, approved_at: Time.now, next_check_at: 1.day.from_now)
    expect { subject.perform }.not_to change(CheckInkReview.jobs, :length)
  end

  it "does not enqueue jobs for unapproved reviews" do
    create(:ink_review, approved_at: nil, next_check_at: 1.hour.ago)
    expect { subject.perform }.not_to change(CheckInkReview.jobs, :length)
  end

  it "respects BATCH_SIZE" do
    stub_const("EnqueueInkReviewChecks::BATCH_SIZE", 2)
    create_list(:ink_review, 5, approved_at: Time.now, next_check_at: 1.hour.ago)
    expect { subject.perform }.to change(CheckInkReview.jobs, :length).by(2)
  end

  it "stagger-schedules jobs by STAGGER_INTERVAL seconds" do
    create_list(:ink_review, 3, approved_at: Time.now, next_check_at: 1.hour.ago)
    subject.perform
    jobs = CheckInkReview.jobs
    now = Time.now.to_f
    expect(jobs[0]["at"]).to be_nil # immediate
    expect(jobs[1]["at"] - now).to be_within(2).of(EnqueueInkReviewChecks::STAGGER_INTERVAL)
    expect(jobs[2]["at"] - now).to be_within(2).of(EnqueueInkReviewChecks::STAGGER_INTERVAL * 2)
  end

  it "claims enqueued reviews by pushing next_check_at past the stagger window" do
    due = create(:ink_review, approved_at: Time.now, next_check_at: 1.hour.ago)
    span = EnqueueInkReviewChecks::BATCH_SIZE * EnqueueInkReviewChecks::STAGGER_INTERVAL
    subject.perform
    expect(due.reload.next_check_at).to be_within(5.seconds).of(span.seconds.from_now)
  end

  it "does not re-enqueue in-flight reviews on a subsequent run" do
    create(:ink_review, approved_at: Time.now, next_check_at: 1.hour.ago)
    subject.perform
    expect { subject.perform }.not_to change(CheckInkReview.jobs, :length)
  end

  it "processes oldest-due reviews first" do
    older = create(:ink_review, approved_at: Time.now, next_check_at: 2.days.ago)
    newer = create(:ink_review, approved_at: Time.now, next_check_at: 1.hour.ago)
    stub_const("EnqueueInkReviewChecks::BATCH_SIZE", 1)
    subject.perform
    expect(CheckInkReview.jobs.first["args"]).to eq([older.id])
    expect(CheckInkReview.jobs.first["args"]).not_to eq([newer.id])
  end
end
