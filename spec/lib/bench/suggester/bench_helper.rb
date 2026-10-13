require "rails_helper"
require Rails.root.join("lib/bench/suggester").to_s

module BenchSuggesterHelpers
  def suggester_prompt(pen_ids: [], ink_ids: [], instruction: nil, rejected: nil)
    pens =
      CSV.generate do |csv|
        csv << ["pen id", "fountain pen name"]
        pen_ids.each { |id| csv << [id, "\"Pen #{id}\""] }
      end
    inks =
      CSV.generate do |csv|
        csv << ["ink id", "ink name", "description"]
        ink_ids.each do |id|
          csv << [id, "\"Ink #{id}\"", "A description.\n\nWith a blank line, inside quotes"]
        end
      end
    parts = [
      "Given the following fountain pens:\n#{pens}\n\nPens have the following average statistics:\n" \
        "{\"average_usage\":1.0}\n\nGiven the following inks:\n#{inks}\n\n" \
        "Inks have the following average statistics:\n{\"average_usage\":1.0}\n\n" \
        "Which combination of ink and fountain pen should I use and why?"
    ]
    if instruction
      parts << "IMPORTANT: Take extra care to follow these additional instructions:\n#{instruction}"
    end
    if rejected
      parts << "The following suggestions were rejected. Do not recommend them again:\n#{JSON.generate(rejected)}"
    end
    parts.join("\n\n")
  end

  def suggester_log(
    user:,
    created_at: Time.current,
    extra_data: {},
    model: "gpt-4.1-mini-2025-04-14",
    **prompt
  )
    create(
      :agent_log,
      name: "PenAndInkSuggester",
      owner: user,
      created_at:,
      transcript: [
        { "role" => "system", "content" => "" },
        { "role" => "user", "content" => suggester_prompt(**prompt) },
        { "role" => "assistant", "content" => "", "tool_calls" => [] }
      ],
      extra_data:,
      usage: {
        "model" => model,
        "prompt_tokens" => 1000,
        "completion_tokens" => 100,
        "total_tokens" => 1100
      }
    )
  end
end

RSpec.configure do |config|
  config.include BenchSuggesterHelpers, file_path: %r{spec/lib/bench/suggester}
end
