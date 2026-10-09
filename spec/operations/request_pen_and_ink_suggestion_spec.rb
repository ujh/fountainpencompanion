require "rails_helper"

describe RequestPenAndInkSuggestion do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  after { travel_back }

  describe "requesting a suggestion" do
    it "enqueues the worker with the input, the rejected pairs and the enqueue time" do
      freeze_time
      rejected = [{ "ink_id" => 1, "pen_id" => 2 }]

      result =
        described_class.new(
          user:,
          extra_user_input: "Blue please",
          rejected_suggestions: rejected
        ).perform

      expect(result[:suggestion_id]).to start_with("request-pen-and-ink-suggestion-")
      expect(SchedulePenAndInkSuggestion.jobs.sole["args"]).to eq(
        [user.id, result[:suggestion_id], "Blue please", rejected, Time.current.to_f]
      )
    end

    it "enqueues on the interactive queue" do
      described_class.new(user:).perform

      expect(SchedulePenAndInkSuggestion.jobs.sole["queue"]).to eq("interactive")
    end

    it "passes an empty list when the rejected suggestions are nil" do
      described_class.new(user:, rejected_suggestions: nil).perform

      expect(SchedulePenAndInkSuggestion.jobs.sole["args"][3]).to eq([])
    end

    context "when the daily cap is reached" do
      before { create_list(:agent_log, 20, name: "PenAndInkSuggester", owner: user) }

      it "does not enqueue the worker" do
        described_class.new(user:).perform

        expect(SchedulePenAndInkSuggestion.jobs).to be_empty
      end

      it "makes the cap message available under the returned suggestion id" do
        result = described_class.new(user:).perform

        expect(Rails.cache.read(result[:suggestion_id])).to eq(
          { message: PenAndInkSuggester::DailyCap.new(user).message }
        )
      end
    end

    it "enqueues the worker one run below the daily cap" do
      create_list(:agent_log, 19, name: "PenAndInkSuggester", owner: user)

      described_class.new(user:).perform

      expect(SchedulePenAndInkSuggestion.jobs.size).to eq(1)
    end
  end

  describe "reading a suggestion" do
    let(:suggestion_id) { "request-pen-and-ink-suggestion-abc" }

    def read
      described_class.new(user:, suggestion_id:).perform
    end

    it "returns an empty hash while the suggestion is pending" do
      expect(read).to eq({})
    end

    it "loads the suggested ink and pen and renders the message" do
      ink = create(:collected_ink, user:)
      pen = create(:collected_pen, user:)
      Rails.cache.write(suggestion_id, { message: "**Bold** choice", ink: ink.id, pen: pen.id })

      result = read

      expect(result[:ink]).to eq(ink)
      expect(result[:pen]).to eq(pen)
      expect(result[:message]).to include("<strong>Bold</strong>")
    end

    it "does not load another user's ink or pen" do
      other_user = create(:user)
      ink = create(:collected_ink, user: other_user)
      pen = create(:collected_pen, user: other_user)
      Rails.cache.write(suggestion_id, { message: "Try these", ink: ink.id, pen: pen.id })

      result = read

      expect(result[:ink]).to be_nil
      expect(result[:pen]).to be_nil
    end

    it "returns an error result with its message and status" do
      Rails.cache.write(suggestion_id, PenAndInkSuggester.error_result)

      result = read

      expect(result[:message]).to eq(FpcFormatter.render(PenAndInkSuggester::ERROR_MESSAGE))
      expect(result[:status]).to eq("error")
      expect(result[:ink]).to be_nil
      expect(result[:pen]).to be_nil
    end

    it "tolerates a result without a message" do
      Rails.cache.write(suggestion_id, { ink: nil, pen: nil })

      expect(read).to eq({ ink: nil, pen: nil })
    end
  end
end
