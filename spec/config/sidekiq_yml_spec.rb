require "rails_helper"

RSpec.describe "config/sidekiq.yml" do
  let(:queues) do
    config =
      YAML.safe_load(
        ERB.new(Rails.root.join("config/sidekiq.yml").read).result,
        permitted_classes: [Symbol]
      )
    config.fetch(:queues)
  end

  it "lists the interactive queue before the agents queue" do
    expect(queues.index("interactive")).to be < queues.index("agents")
  end

  it "processes the suggestion worker's queue" do
    expect(queues).to include(SchedulePenAndInkSuggestion.get_sidekiq_options["queue"])
  end
end
