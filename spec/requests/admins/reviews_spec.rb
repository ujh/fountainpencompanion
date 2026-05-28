require "rails_helper"

describe "Admins::Reviews" do
  let(:admin) { create(:user, :admin) }

  describe "GET /admins/reviews" do
    it "requires authentication" do
      get "/admins/reviews"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders successfully" do
        get "/admins/reviews"
        expect(response).to be_successful
      end

      describe "transcript section" do
        let(:agent_processed_review) do
          review =
            create(
              :ink_review,
              extra_data: {
                "action" => "approve_review",
                "explanation_of_decision" => "ok"
              },
              approved_at: Time.current,
              agent_approved: true
            )
          create(
            :ink_review_submission,
            ink_review: review,
            macro_cluster: review.macro_cluster,
            url: review.url
          )
          review
        end

        it "renders the latest ReviewApprover transcript inside a collapsed <details>" do
          agent_processed_review.agent_logs.create!(
            name: "ReviewApprover",
            state: "approved",
            transcript: [
              { "role" => "system", "content" => "system msg" },
              { "role" => "user", "content" => "user msg" },
              { "role" => "assistant", "content" => "assistant msg" }
            ]
          )

          get "/admins/reviews"

          expect(response.body).to include("Transcript")
          expect(response.body).to include("<details>")
          expect(response.body).to include("Show LLM conversation (3 messages)")
          expect(response.body).to include("system msg")
          expect(response.body).to include("user msg")
          expect(response.body).to include("assistant msg")
        end

        it "picks the latest ReviewApprover log when multiple exist" do
          agent_processed_review.agent_logs.create!(
            name: "ReviewApprover",
            state: "rejected",
            transcript: [{ "role" => "user", "content" => "old run" }],
            created_at: 2.days.ago
          )
          agent_processed_review.agent_logs.create!(
            name: "ReviewApprover",
            state: "approved",
            transcript: [{ "role" => "user", "content" => "latest run" }]
          )

          get "/admins/reviews"

          expect(response.body).to include("latest run")
          expect(response.body).not_to include("old run")
        end

        it "omits the transcript section when no ReviewApprover log exists" do
          agent_processed_review # ensure review exists without an agent log
          get "/admins/reviews"
          expect(response.body).not_to include("Show LLM conversation")
        end
      end

      describe "stats table" do
        def manually_processed_review(agent_action:, final:)
          review =
            create(
              :ink_review,
              extra_data: {
                "action" => agent_action,
                "explanation_of_decision" => "..."
              }
            )
          create(
            :ink_review_submission,
            ink_review: review,
            macro_cluster: review.macro_cluster,
            url: review.url
          )
          if final == :approved
            review.approve!
          else
            review.reject!
          end
          review
        end

        it "renders a table even when there are no reviews to analyse" do
          get "/admins/reviews"
          expect(response.body).to include("total")
          expect(response.body).to include("0.000%")
          expect(response.body).not_to include("NaN")
        end

        it "counts agent decisions that match the human verdict as correct and mismatches as incorrect" do
          # 3 cases where the agent approved
          2.times { manually_processed_review(agent_action: "approve_review", final: :approved) }
          manually_processed_review(agent_action: "approve_review", final: :rejected)

          # 5 cases where the agent rejected
          4.times { manually_processed_review(agent_action: "reject_review", final: :rejected) }
          manually_processed_review(agent_action: "reject_review", final: :approved)

          # Excluded: empty extra_data
          create(:ink_review, extra_data: {}).approve!
          # Excluded: still waiting on a human (agent_processed scope)
          waiting =
            create(
              :ink_review,
              image: "http://example.com/img.png",
              extra_data: {
                "action" => "approve_review"
              },
              approved_at: Time.current,
              agent_approved: true
            )
          create(
            :ink_review_submission,
            ink_review: waiting,
            macro_cluster: waiting.macro_cluster,
            url: waiting.url
          )
          # Excluded: verdict older than the 6-month stats window
          stale = manually_processed_review(agent_action: "approve_review", final: :approved)
          stale.update_columns(approved_at: 7.months.ago)

          get "/admins/reviews"
          stats = controller.instance_variable_get(:@stats)

          expect(stats[:total]).to include(count: 8, correct: 6, incorrect: 2)
          expect(stats["approve_review"]).to include(count: 3, correct: 2, incorrect: 1)
          expect(stats["reject_review"]).to include(count: 5, correct: 4, incorrect: 1)
        end

        it "reports agent-submitted reviews when the bettong.net user owns the submission" do
          agent_user = create(:user, :admin, email: "urban@bettong.net")
          other_user = create(:user)

          agent_review = manually_processed_review(agent_action: "approve_review", final: :approved)
          agent_review.ink_review_submissions.create!(
            user: agent_user,
            macro_cluster: agent_review.macro_cluster,
            url: agent_review.url
          )

          other_review = manually_processed_review(agent_action: "approve_review", final: :approved)
          other_review.ink_review_submissions.create!(
            user: other_user,
            macro_cluster: other_review.macro_cluster,
            url: other_review.url
          )

          get "/admins/reviews"
          stats = controller.instance_variable_get(:@stats)

          expect(stats[:agent_submitted]).to include(count: 1, correct: 1, incorrect: 0)
        end
      end
    end
  end

  describe "PUT /admins/reviews/:id" do
    let(:ink_review) { create(:ink_review) }

    it "requires authentication" do
      put "/admins/reviews/#{ink_review.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "approves the review" do
        expect do put "/admins/reviews/#{ink_review.id}" end.to change {
          ink_review.reload.approved?
        }.from(false).to(true)
      end

      it "keeps redirects to the reviews index page with the page param if another review exists" do
        create(:ink_review, approved_at: Time.current, agent_approved: true)
        put "/admins/reviews/#{ink_review.id}?page=2"
        expect(response).to redirect_to("/admins/reviews?page=2")
      end
    end
  end

  describe "DELETE /admins/reviews/:id" do
    let(:ink_review) { create(:ink_review) }

    it "requires authentication" do
      delete "/admins/reviews/#{ink_review.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "rejects the review" do
        expect do delete "/admins/reviews/#{ink_review.id}" end.to change {
          ink_review.reload.rejected?
        }.from(false).to(true)
      end

      it "ignores the YouTube channel when rejecting a review with ignore_youtube_channel param" do
        youtube_channel = create(:you_tube_channel, ignored: false)
        ink_review_with_channel = create(:ink_review, you_tube_channel: youtube_channel)

        expect do
          delete "/admins/reviews/#{ink_review_with_channel.id}?ignore_youtube_channel=true"
        end.to change { youtube_channel.reload.ignored? }.from(false).to(true)

        expect(ink_review_with_channel.reload.rejected?).to be true
      end
    end
  end
end
