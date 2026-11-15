require "rails_helper"
require Rails.root.join(".claude/skills/review-ignored-inks/scripts/lib/console_script").to_s

RSpec.describe IgnoredInksReview::ConsoleScript do
  let(:template) do
    Rails.root.join(".claude/skills/review-ignored-inks/scripts/console_template.rb").read
  end

  def render(units)
    described_class.render(template, "2026-11-15", "01-changes", "assign 1", units)
  end

  def decisions_json(script)
    script[/JSON\.parse\(<<~'DECISIONS'\)\n(.*?)\n\s*DECISIONS\n/m, 1]
  end

  {
    "DEL" => ["\u007f", "\\u007f"],
    "first C1 control" => ["\u0080", "\\u0080"],
    "C1 control sequence introducer" => ["\u009b", "\\u009b"],
    "last C1 control" => ["\u009f", "\\u009f"],
    "soft hyphen" => ["\u00ad", "\\u00ad"],
    "zero-width space" => ["\u200b", "\\u200b"],
    "right-to-left override" => ["\u202e", "\\u202e"],
    "left-to-right isolate" => ["\u2066", "\\u2066"],
    "byte order mark" => ["\ufeff", "\\ufeff"],
    "line separator" => ["\u2028", "\\u2028"],
    "paragraph separator" => ["\u2029", "\\u2029"],
    "format character outside the BMP" => ["\u{e0041}", "\\udb40\\udc41"]
  }.each do |label, (character, escape)|
    it "escapes a #{label}" do
      script = render([{ "id" => 1, "name" => "Ink#{character}Name" }])

      expect(script).not_to include(character)
      expect(script).to include("Ink#{escape}Name")
    end
  end

  it "parses back to the same units" do
    name =
      "Ink \u007f\u0085\u009f\u00ad\u200b\u200d\u202e\u2028\u2029\ufeff\u{e0041} \"q\" \\ \n\t end"
    units = [
      { "id" => 1, "name" => name, "evidence" => ["https://example.com/a?b=1&c=<2>"] },
      {
        "merge" => {
          "id" => "m1-2",
          "from" => 2,
          "into" => 1,
          "notes" => "#{name} \u{1f469}\u200d\u{1f52c}"
        }
      }
    ]

    expect(JSON.parse(decisions_json(render(units)))).to eq(units)
  end

  it "keeps ordinary names as JSON.generate writes them" do
    units = [
      { "id" => 1, "name" => "Pelikan Édelstein Aquamarine", "reason" => "Línea \"Edelstein\"" },
      { "id" => 2, "name" => "色彩雫 月夜 / 이로시즈쿠 / Iroshizuku Tsuki-yo" },
      { "id" => 3, "name" => "Octopus 🐙 Write & Draw <Black> ✒️" }
    ]

    script = render(units)

    units.each { |unit| expect(script).to include("    #{JSON.generate(unit)}") }
  end

  it "renders a script Ruby can compile" do
    script = render([{ "id" => 1, "name" => "Ink \u2028\u202e Name" }])

    expect { RubyVM::InstructionSequence.compile(script) }.not_to raise_error
  end
end
