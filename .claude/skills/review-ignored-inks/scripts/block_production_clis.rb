# PreToolUse hook registered in SKILL.md. Refuses Bash commands that run the
# production CLIs (doctl, fly, flyctl, gh) and tool calls that touch their
# credential files. Prints a deny decision as JSON; prints nothing for every
# other call, including input it cannot parse, so the normal permission flow
# decides.
require "json"

module IgnoredInksReview
  module ProductionCliGuard
    CLI = %r{(?:\A|[\s;&|()`'"/\\])(?:doctl|flyctl|fly|gh)(?=\z|[\s;&|()`'"<>])}i
    CREDENTIALS =
      %r{Library/Application(?:\\?\s)Support/doctl|\.config/doctl|\.config/gh(?=\z|[/\s'"*])|(?:\A|[/~])\.fly(?=\z|[/\s'"*])}i
    FIELDS = {
      "Bash" => %w[command],
      "Read" => %w[file_path],
      "Grep" => %w[path glob],
      "Glob" => %w[path pattern]
    }.freeze

    module_function

    def reason(input)
      return unless input.is_a?(Hash) && input["tool_input"].is_a?(Hash)

      tool = input["tool_name"]
      values = FIELDS.fetch(tool, []).map { |field| input["tool_input"][field] }.grep(String)
      if tool == "Bash" && values.any? { |value| value.match?(CLI) }
        return "doctl, fly and gh are blocked for the rest of this session (review-ignored-inks)."
      end

      values << values.join("/") if values.size > 1
      return unless values.any? { |value| value.match?(CREDENTIALS) }

      "The credential files of doctl, fly and gh are blocked for the rest of this session " \
        "(review-ignored-inks)."
    end

    def run(stdin, stdout)
      message = reason(JSON.parse(stdin.read))
      return unless message

      stdout.puts JSON.generate(
                    "hookSpecificOutput" => {
                      "hookEventName" => "PreToolUse",
                      "permissionDecision" => "deny",
                      "permissionDecisionReason" => message
                    }
                  )
    rescue JSON::ParserError
      nil
    end
  end
end

IgnoredInksReview::ProductionCliGuard.run($stdin, $stdout) if $PROGRAM_NAME == __FILE__
