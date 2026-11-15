require "rails_helper"
require "open3"

require Rails.root.join(".claude/skills/review-ignored-inks/scripts/block_production_clis").to_s

RSpec.describe IgnoredInksReview::ProductionCliGuard do
  def self.bash(command)
    { "tool_name" => "Bash", "tool_input" => { "command" => command } }
  end

  def bash(command) = self.class.bash(command)

  def run_hook(stdin)
    script = Rails.root.join(".claude/skills/review-ignored-inks/scripts/block_production_clis.rb")
    Open3.capture3("ruby", script.to_s, stdin_data: stdin)
  end

  [
    "doctl databases list",
    "fly status -a fountainpencompanion",
    "flyctl secrets list",
    "gh api user",
    "cd tmp && gh pr list",
    "ls; doctl version",
    "echo hi | gh auth token",
    "sh -c 'doctl databases list'",
    "bash -c \"fly ssh console\"",
    "/opt/homebrew/bin/doctl version",
    "\\gh auth status",
    "env DIGITALOCEAN_CONTEXT=x doctl account get",
    "x=$(gh auth token)",
    "`flyctl auth token`",
    "DOCTL version"
  ].each do |command|
    it "blocks #{command.inspect}" do
      expect(described_class.reason(bash(command))).to match(/doctl, fly and gh are blocked/)
    end
  end

  [
    "cat fly.toml",
    "ls .github/workflows",
    "echo flyer lightfly",
    "git push origin gh-pages",
    "docker-compose exec -T app bundle exec rspec spec/models/flyweight_spec.rb",
    "ruby .claude/skills/review-ignored-inks/scripts/lookup.rb search 'Ghost Grey'",
    "grep -r doctlx ."
  ].each do |command|
    it "allows #{command.inspect}" do
      expect(described_class.reason(bash(command))).to be_nil
    end
  end

  [
    bash("cat ~/Library/Application\\ Support/doctl/config.yaml"),
    bash("cat \"$HOME/Library/Application Support/doctl/config.yaml\""),
    bash("ls ~/.config/doctl/"),
    bash("cat ~/.fly/config.yml"),
    bash("tar c ~/.config/gh/"),
    { "tool_name" => "Read", "tool_input" => { "file_path" => "/Users/u/.config/gh/hosts.yml" } },
    {
      "tool_name" => "Read",
      "tool_input" => {
        "file_path" => "/Users/u/Library/Application Support/doctl/config.yaml"
      }
    },
    { "tool_name" => "Grep", "tool_input" => { "pattern" => "token", "path" => "/Users/u/.fly" } },
    {
      "tool_name" => "Grep",
      "tool_input" => {
        "pattern" => "token",
        "path" => "/Users/u",
        "glob" => ".config/gh/*"
      }
    },
    { "tool_name" => "Glob", "tool_input" => { "pattern" => ".fly/**", "path" => "/Users/u" } },
    {
      "tool_name" => "Glob",
      "tool_input" => {
        "pattern" => "*",
        "path" => "/Users/u/.config/doctl"
      }
    }
  ].each do |input|
    it "blocks credential access in #{input.to_json}" do
      expect(described_class.reason(input)).to match(/credential files/)
    end
  end

  [
    { "tool_name" => "Read", "tool_input" => { "file_path" => "/app/fly.toml" } },
    { "tool_name" => "Read", "tool_input" => { "file_path" => "/app/.github/workflows/ci.yml" } },
    { "tool_name" => "Read", "tool_input" => { "file_path" => "/Users/u/.config/ghostty/config" } },
    { "tool_name" => "Glob", "tool_input" => { "pattern" => "**/*.rb", "path" => "/app" } },
    { "tool_name" => "WebFetch", "tool_input" => { "url" => "https://fly.io/docs/.fly/x" } }
  ].each do |input|
    it "allows #{input.to_json}" do
      expect(described_class.reason(input)).to be_nil
    end
  end

  it "prints a deny decision for a blocked call" do
    stdout, stderr, status = run_hook(JSON.generate(bash("doctl version")))

    expect(status).to be_success
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to eq(
      "hookSpecificOutput" => {
        "hookEventName" => "PreToolUse",
        "permissionDecision" => "deny",
        "permissionDecisionReason" =>
          "doctl, fly and gh are blocked for the rest of this session (review-ignored-inks)."
      }
    )
  end

  it "prints nothing for an allowed call" do
    stdout, _stderr, status = run_hook(JSON.generate(bash("ls -la")))

    expect(status).to be_success
    expect(stdout).to be_empty
  end

  ["not json", "", "[1, 2]", "{\"tool_name\": \"Bash\"}"].each do |stdin|
    it "leaves malformed input #{stdin.inspect} to the normal permission flow" do
      stdout, stderr, status = run_hook(stdin)

      expect(status).to be_success
      expect(stdout).to be_empty
      expect(stderr).to be_empty
    end
  end
end
