require "rails_helper"

RSpec.describe "RubyLLM tool names" do
  before do
    stub_const(
      "RubyLlmToolNameSpec::AgentWithTools::AssignClusterTool",
      Class.new(RubyLLM::Tool) { description "Assign a cluster" }
    )
    stub_const(
      "RubyLlmToolNameSpec::AgentWithTools::RecordSuggestion",
      Class.new(RubyLLM::Tool) { description "Record a suggestion" }
    )
  end

  it "derives the name from the class name without the module prefix" do
    tool = RubyLlmToolNameSpec::AgentWithTools::RecordSuggestion.new

    expect(tool.name).to eq("record_suggestion")
  end

  it "drops a trailing _tool" do
    tool = RubyLlmToolNameSpec::AgentWithTools::AssignClusterTool.new

    expect(tool.name).to eq("assign_cluster")
  end

  it "keeps an explicitly defined name" do
    tool_class =
      Class.new(RubyLlmToolNameSpec::AgentWithTools::RecordSuggestion) do
        def name = "legacy_record_suggestion"
      end

    expect(tool_class.new.name).to eq("legacy_record_suggestion")
  end

  it "cannot derive a name for an anonymous tool class" do
    tool = Class.new(RubyLLM::Tool) { description "Anonymous" }.new

    expect { tool.name }.to raise_error(NoMethodError)
  end
end
