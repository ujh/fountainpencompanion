module ConstraintExtractorHelpers
  def extractor_request?(request)
    JSON
      .parse(request.body)
      .fetch("tools", [])
      .any? { |tool| tool.dig("function", "name") == "set_constraints" }
  end

  def set_constraints_completion(
    arguments = {},
    id: "call_constraints",
    model: "gpt-6-luna-2026-09-22",
    arguments_json: arguments.to_json
  )
    {
      "id" => "chatcmpl-constraints",
      "object" => "chat.completion",
      "model" => model,
      "choices" => [
        {
          "index" => 0,
          "message" => {
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              {
                "id" => id,
                "type" => "function",
                "function" => {
                  "name" => "set_constraints",
                  "arguments" => arguments_json
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => {
        "prompt_tokens" => 1_000,
        "completion_tokens" => 100,
        "total_tokens" => 1_100
      }
    }
  end

  def stub_constraint_extractor(constraints)
    allow_any_instance_of(PenAndInkConstraintExtractor).to receive(:perform).and_return(
      constraints && PenAndInkSuggestion::Constraints.from_h(constraints)
    )
  end
end
