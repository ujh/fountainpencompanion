require "rails_helper"

describe WordDiff do
  def diff(old_text, new_text)
    described_class.new(old_text, new_text).html
  end

  # Expectations generated with differ 0.1.2 on the escaped texts:
  # Differ.diff_by_word(h(new), h(old)).format_as(:html)
  {
    "identical texts" => ["Blue ink", "Blue ink", "Blue ink"],
    "a replaced word" => [
      "Pale blue ink",
      "Deep blue ink",
      '<del class="differ">Pale</del><ins class="differ">Deep</ins> blue ink'
    ],
    "an inserted word" => [
      "A blue ink",
      "A deep blue ink",
      'A <ins class="differ">deep </ins>blue ink'
    ],
    "a deleted word" => [
      "A deep blue ink",
      "A blue ink",
      'A <del class="differ">deep </del>blue ink'
    ],
    "mixed changes" => [
      "Shades little, and a hint of red sheen!",
      "Shades a lot, with a hint of gold sheen.",
      'Shades <del class="differ">little, and </del>a <ins class="differ">lot, with a </ins>hint of ' \
        '<del class="differ">red</del><ins class="differ">gold</ins> sheen' \
        '<del class="differ">!</del><ins class="differ">.</ins>'
    ],
    "a rewritten sentence" => [
      "Purple with a red sheen, very wet.",
      "A dark teal that shades to green.",
      '<del class="differ">Purple</del><ins class="differ">A</ins> ' \
        '<del class="differ">with</del><ins class="differ">dark</ins> ' \
        '<del class="differ">a</del><ins class="differ">teal</ins> ' \
        '<del class="differ">red</del><ins class="differ">that</ins> ' \
        '<del class="differ">sheen, very</del><ins class="differ">shades</ins> ' \
        '<del class="differ">wet</del><ins class="differ">to green</ins>.'
    ],
    "changed whitespace" => [
      "Blue ink with sheen",
      "Blue  ink\nwith sheen",
      "Blue<ins class=\"differ\">  ink\nwith</ins> <del class=\"differ\">ink with </del>sheen"
    ],
    "characters that need escaping" => [
      "Tom and Jerry \"Blue\"",
      "Tom & Jerry \"Red\"",
      'Tom<del class="differ"> and Jerry</del> &<ins class="differ">amp; Jerry &</ins>quot;' \
        '<del class="differ">Blue</del><ins class="differ">Red</ins>&quot;'
    ],
    "a change next to an escaped character" => [
      "edition,\" ink",
      "edition\" ink",
      'edition<del class="differ">,&</del><ins class="differ">&</ins>quot; ink'
    ],
    "CJK text" => [
      "春日纪Spring",
      "春日纪 Spring",
      '<del class="differ">春日纪Spring</del><ins class="differ">春日纪 Spring</ins>'
    ],
    "an empty new text" => ["Old ink", "", '<del class="differ">Old ink</del>'],
    "an empty old text" => ["", "New ink", '<ins class="differ">New ink</ins>'],
    "two empty texts" => ["", "", ""]
  }.each do |name, (old_text, new_text, expected)|
    it "renders #{name} like differ" do
      expect(diff(old_text, new_text)).to eq(expected)
    end
  end

  it "escapes HTML in the texts" do
    expect(diff("safe", "<script>alert(1)</script>")).to eq(
      '<del class="differ">safe</del><ins class="differ">&lt;script&gt;alert(1)&lt;/script&gt;</ins>'
    )
  end

  it "returns HTML-safe output" do
    expect(diff("A blue ink", "A deep blue ink")).to be_html_safe
    expect(diff("x", (["x"] * 1_501).join(" "))).to be_html_safe
  end

  it "treats nil as an empty text" do
    expect(diff("Old ink", nil)).to eq('<del class="differ">Old ink</del>')
  end

  describe "size limit" do
    let(:at_limit) { (["x"] * 1_500).join(" ") }
    let(:over_limit) { (["x"] * 1_501).join(" ") }

    it "diffs texts with up to 3,000 tokens" do
      expect(at_limit.split(/\b/).length).to eq(2_999)

      expect(diff(at_limit, at_limit.sub(/x\z/, "y"))).to eq(
        "#{at_limit.chop}<del class=\"differ\">x</del><ins class=\"differ\">y</ins>"
      )
    end

    it "does not diff when the new text has more than 3,000 tokens" do
      expect(over_limit.split(/\b/).length).to eq(3_001)

      expect(diff("x", over_limit)).to eq('<em class="text-muted">Too long to compare.</em>')
    end

    it "does not diff when the old text has more than 3,000 tokens" do
      expect(diff(over_limit, "x")).to eq('<em class="text-muted">Too long to compare.</em>')
    end

    it "diffs long texts with few tokens" do
      long_word = "a" * 5_000

      expect(diff("#{long_word} pen", "#{long_word} ink")).to eq(
        "#{long_word} <del class=\"differ\">pen</del><ins class=\"differ\">ink</ins>"
      )
    end
  end

  it "returns the same HTML when called twice" do
    word_diff = described_class.new("A blue ink pen", "A blue")

    expect(word_diff.html).to eq('A blue<del class="differ"> ink pen</del>')
    expect(word_diff.html).to eq('A blue<del class="differ"> ink pen</del>')
  end
end
