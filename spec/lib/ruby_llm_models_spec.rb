require "rails_helper"

RSpec.describe RubyLlmModels do
  after { RubyLLM.models.all.reject! { |model| model.id.start_with?("gpt-9-") } }

  describe ".find" do
    it "finds a model the registry knows under the OpenAI provider" do
      expect(described_class.find("gpt-4.1-mini")).to have_attributes(
        id: "gpt-4.1-mini",
        provider: "openai"
      )
    end

    it "is nil for a model the registry does not know" do
      expect(described_class.find("gpt-9-unknown")).to be_nil
    end
  end

  describe ".register" do
    it "adds an OpenAI text model with the given capabilities, once" do
      2.times { described_class.register("gpt-9-new", capabilities: %w[function_calling]) }

      expect(RubyLLM.models.all.count { |model| model.id == "gpt-9-new" }).to eq(1)
      model = described_class.find("gpt-9-new")
      expect(model).to have_attributes(
        name: "gpt-9-new",
        provider: "openai",
        capabilities: %w[function_calling]
      )
      expect(model.modalities).to have_attributes(input: %w[text], output: %w[text])
    end

    it "leaves a known model's registry entry alone" do
      known = described_class.find("gpt-4.1-mini")

      expect { described_class.register("gpt-4.1-mini", capabilities: %w[reasoning]) }.not_to(
        change { RubyLLM.models.all.size }
      )
      expect(described_class.find("gpt-4.1-mini")).to be(known)
    end
  end

  describe ".register_unlisted" do
    it "registers every unlisted model at most once" do
      2.times { described_class.register_unlisted }

      described_class::UNLISTED.each do |model_id, capabilities|
        expect(RubyLLM.models.all.count { |model| model.id == model_id }).to eq(1)
        expect(described_class.find(model_id).capabilities).to match_array(capabilities)
      end
    end
  end
end
