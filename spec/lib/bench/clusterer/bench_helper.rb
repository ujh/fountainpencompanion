require "rails_helper"
require Rails.root.join("lib/bench/clusterer").to_s

module BenchClustererHelpers
  def bench_case(**overrides)
    Bench::Clusterer::BenchCase.new(
      id: "assign-1",
      kind: "assign",
      log_id: 1,
      micro_cluster_id: 2,
      expected: "approve",
      cluster_id: 3,
      disputed: false,
      explanation: "Same ink.",
      transcript: [],
      inks: [
        {
          "brand_name" => "Pilot",
          "line_name" => "Iroshizuku",
          "ink_name" => "Kon-peki",
          "color" => "#2a6fb0",
          "kind" => "bottle",
          "user_id" => 10
        }
      ],
      **overrides
    )
  end

  def tool_call_response(name, arguments)
    {
      "id" => "chatcmpl-bench",
      "object" => "chat.completion",
      "created" => 1_677_652_288,
      "model" => "gpt-4.1",
      "choices" => [
        {
          "index" => 0,
          "message" => {
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              {
                "id" => "call_bench",
                "type" => "function",
                "function" => {
                  "name" => name,
                  "arguments" => arguments.to_json
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => {
        "prompt_tokens" => 10,
        "completion_tokens" => 5,
        "total_tokens" => 15
      }
    }
  end

  def stub_openai_tool_call(name, arguments)
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      body: tool_call_response(name, arguments).to_json,
      headers: {
        "Content-Type" => "application/json"
      }
    )
  end
end

RSpec.configure do |config|
  config.include BenchClustererHelpers, file_path: %r{spec/lib/bench/clusterer}
end
