require "rails_helper"

describe MergeMacroClusters do
  let!(:source) { create(:macro_cluster, description: "") }
  let!(:target) { create(:macro_cluster, description: "") }
  let(:user) { create(:user) }

  def merge = described_class.new(source, target).perform

  it "moves the micro clusters to the target" do
    micro_clusters = create_list(:micro_cluster, 2, macro_cluster: source)

    merge

    expect(micro_clusters.map { |m| m.reload.macro_cluster_id }).to eq([target.id, target.id])
  end

  it "leaves micro clusters of other macro clusters alone" do
    other = create(:micro_cluster, macro_cluster: create(:macro_cluster))

    expect { merge }.not_to(change { other.reload.macro_cluster_id })
  end

  it "deletes the source" do
    merge

    expect(MacroCluster.exists?(source.id)).to be(false)
  end

  it "returns the target" do
    expect(merge).to eq(target)
  end

  it "moves ink reviews to the target" do
    review = create(:ink_review, macro_cluster: source)

    merge

    expect(review.reload.macro_cluster).to eq(target)
  end

  it "keeps the target's review when both have a review with the same url" do
    existing = create(:ink_review, macro_cluster: target, url: "https://example.com/review")
    duplicate = create(:ink_review, macro_cluster: source, url: "https://example.com/review")

    merge

    expect(InkReview.exists?(duplicate.id)).to be(false)
    expect(target.ink_reviews.reload).to eq([existing])
  end

  it "keeps the source's review when only it is approved" do
    existing = create(:ink_review, macro_cluster: target, url: "https://example.com/review")
    approved =
      create(
        :ink_review,
        macro_cluster: source,
        url: "https://example.com/review",
        approved_at: Time.current
      )
    target_submission =
      create(:ink_review_submission, macro_cluster: target, ink_review: existing, user: user)
    source_submission =
      create(
        :ink_review_submission,
        macro_cluster: source,
        ink_review: approved,
        user: create(:user)
      )

    merge

    expect(InkReview.exists?(existing.id)).to be(false)
    expect(target.ink_reviews.reload).to eq([approved])
    expect(target_submission.reload.ink_review).to eq(approved)
    expect(source_submission.reload.ink_review).to eq(approved)
  end

  it "keeps the target's review when both are approved" do
    existing =
      create(
        :ink_review,
        macro_cluster: target,
        url: "https://example.com/review",
        approved_at: Time.current
      )
    create(
      :ink_review,
      macro_cluster: source,
      url: "https://example.com/review",
      approved_at: Time.current
    )

    merge

    expect(target.ink_reviews.reload).to eq([existing])
  end

  it "moves review submissions to the target and its matching review" do
    create(:ink_review, macro_cluster: target, url: "https://example.com/review")
    duplicate = create(:ink_review, macro_cluster: source, url: "https://example.com/review")
    submission =
      create(
        :ink_review_submission,
        macro_cluster: source,
        ink_review: duplicate,
        user: user,
        url: "https://example.com/review"
      )

    merge

    submission.reload
    expect(submission.macro_cluster).to eq(target)
    expect(submission.ink_review.macro_cluster).to eq(target)
  end

  it "moves review submissions without a review" do
    submission = create(:ink_review_submission, macro_cluster: source, user: user)

    merge

    expect(submission.reload.macro_cluster).to eq(target)
    expect(submission.ink_review).to be_nil
  end

  it "moves review submissions that no longer pass validation" do
    submission =
      build(
        :ink_review_submission,
        macro_cluster: source,
        user: user,
        url: "https://www.instagram.com/p/abc"
      )
    submission.save!(validate: false)

    merge

    expect(submission.reload.macro_cluster).to eq(target)
  end

  it "drops a submission the same user already made for the target" do
    create(:ink_review_submission, macro_cluster: target, user: user, url: "https://example.com/a")
    duplicate =
      create(
        :ink_review_submission,
        macro_cluster: source,
        user: user,
        url: "https://EXAMPLE.com/a"
      )

    merge

    expect(InkReviewSubmission.exists?(duplicate.id)).to be(false)
    expect(InkReviewSubmission.where(macro_cluster: target).count).to eq(1)
  end

  it "points pending assignments to the source at the target" do
    owner = create(:micro_cluster)
    assignment = { "action" => "assign_to_cluster", "cluster_id" => source.id }
    processing = create(:agent_log, :ink_clusterer, owner: owner, extra_data: assignment)
    waiting =
      create(
        :agent_log,
        :ink_clusterer,
        :waiting_for_approval,
        owner: owner,
        extra_data: assignment
      )

    merge

    expect(processing.reload.extra_data["cluster_id"]).to eq(target.id)
    expect(waiting.reload.extra_data["cluster_id"]).to eq(target.id)
  end

  it "leaves processed and unrelated clusterer logs alone" do
    owner = create(:micro_cluster)
    assignment = { "action" => "assign_to_cluster", "cluster_id" => source.id }
    logs = [
      create(:agent_log, :ink_clusterer, :approved, owner: owner, extra_data: assignment),
      create(:agent_log, :ink_clusterer, :rejected, owner: owner, extra_data: assignment),
      create(
        :agent_log,
        :ink_clusterer,
        owner: owner,
        extra_data: {
          "action" => "assign_to_cluster",
          "cluster_id" => create(:macro_cluster).id
        }
      ),
      create(:agent_log, owner: owner, extra_data: assignment)
    ]

    expect { merge }.not_to(change { logs.map { |log| log.reload.extra_data } })
  end

  it "locks both clusters, the lower id first" do
    newer = create(:macro_cluster)
    locked_ids = []
    record_locks = ->(*, payload) do
      lock =
        payload[:sql].match(
          /FROM "macro_clusters" WHERE "macro_clusters"."id" = (\d+) .*FOR UPDATE/
        )
      locked_ids << lock[1].to_i if lock
    end

    ActiveSupport::Notifications.subscribed(record_locks, "sql.active_record") do
      described_class.new(newer, target).perform
    end

    expect(locked_ids).to eq([target.id, newer.id])
  end

  it "copies the description when the target has none" do
    source.update!(description: "From the source")

    merge

    expect(target.reload.description).to eq("From the source")
  end

  it "keeps the target's description" do
    source.update!(description: "From the source")
    target.update!(description: "From the target")

    merge

    expect(target.reload.description).to eq("From the target")
  end

  it "recalculates the target after the merge is committed" do
    expect { merge }.to change(UpdateMacroCluster.jobs, :size).by(1)
    expect(UpdateMacroCluster.jobs.last["args"]).to eq([target.id])
  end

  it "does not recalculate the target when the merge is rolled back" do
    expect do
      ActiveRecord::Base.transaction do
        merge
        raise ActiveRecord::Rollback
      end
    end.not_to change(UpdateMacroCluster.jobs, :size)
  end

  it "changes nothing when a step fails" do
    micro_cluster = create(:micro_cluster, macro_cluster: source)
    allow(InkReviewSubmission).to receive(:where).and_raise(ActiveRecord::StatementInvalid)

    expect { merge }.to raise_error(ActiveRecord::StatementInvalid)
    expect(micro_cluster.reload.macro_cluster).to eq(source)
  end

  it "refuses to merge a cluster into itself" do
    expect { described_class.new(source, source) }.to raise_error(ArgumentError)
  end
end
