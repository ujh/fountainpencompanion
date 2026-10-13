module RubyLlmModels
  PROVIDER = "openai"
  # Models the registry bundled with the gem does not list yet. Drop an entry once the gem knows it.
  UNLISTED = { "gpt-6-luna" => %w[function_calling reasoning] }.freeze

  def self.find(model_id)
    RubyLLM.models.find(model_id, PROVIDER)
  rescue RubyLLM::ModelNotFoundError
    nil
  end

  def self.register(model_id, capabilities:)
    return if find(model_id)

    RubyLLM.models.all << RubyLLM::Model::Info.new(
      id: model_id,
      name: model_id,
      provider: PROVIDER,
      capabilities:,
      modalities: {
        input: %w[text],
        output: %w[text]
      }
    )
  end

  def self.register_unlisted
    UNLISTED.each { |model_id, capabilities| register(model_id, capabilities:) }
  end
end
