require "rails_helper"

describe RunInkClustererAgent do
  describe "retries" do
    def retry_in(exception)
      described_class.sidekiq_retry_in_block.call(1, exception, {})
    end

    it "retries at most 3 times" do
      expect(described_class.get_sidekiq_options["retry"]).to eq(3)
    end

    it "sends bad requests straight to the dead set" do
      expect(retry_in(RubyLLM::BadRequestError.new("bad request"))).to eq(:kill)
    end

    it "sends context length errors straight to the dead set" do
      expect(retry_in(RubyLLM::ContextLengthExceededError.new("too long"))).to eq(:kill)
    end

    it "uses the default backoff for other errors" do
      expect(retry_in(RubyLLM::ServerError.new("oops"))).to be_nil
    end
  end
end
