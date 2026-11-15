require "rails_helper"

describe WordDiff do
  def diff(new_text, old_text)
    described_class.new(new_text, old_text).html
  end

  # Expectations generated with differ 0.1.2: Differ.diff_by_word(new, old).format_as(:html)
  {
    "identical texts" => ["Blue ink", "Blue ink", "Blue ink"],
    "a replaced word" => [
      "Deep blue ink",
      "Pale blue ink",
      '<del class="differ">Pale</del><ins class="differ">Deep</ins> blue ink'
    ],
    "an inserted word" => [
      "A deep blue ink",
      "A blue ink",
      'A <ins class="differ">deep </ins>blue ink'
    ],
    "a deleted word" => [
      "A blue ink",
      "A deep blue ink",
      'A <del class="differ">deep </del>blue ink'
    ],
    "mixed changes" => [
      "Shades a lot, with a hint of gold sheen.",
      "Shades little, and a hint of red sheen!",
      'Shades <del class="differ">little, and </del>a <ins class="differ">lot, with a </ins>hint of ' \
        '<del class="differ">red</del><ins class="differ">gold</ins> sheen' \
        '<del class="differ">!</del><ins class="differ">.</ins>'
    ],
    "a rewritten sentence" => [
      "A dark teal that shades to green.",
      "Purple with a red sheen, very wet.",
      '<del class="differ">Purple</del><ins class="differ">A</ins> ' \
        '<del class="differ">with</del><ins class="differ">dark</ins> ' \
        '<del class="differ">a</del><ins class="differ">teal</ins> ' \
        '<del class="differ">red</del><ins class="differ">that</ins> ' \
        '<del class="differ">sheen, very</del><ins class="differ">shades</ins> ' \
        '<del class="differ">wet</del><ins class="differ">to green</ins>.'
    ],
    "changed whitespace" => [
      "Blue  ink\nwith sheen",
      "Blue ink with sheen",
      "Blue<ins class=\"differ\">  ink\nwith</ins> <del class=\"differ\">ink with </del>sheen"
    ],
    "escaped entities" => [
      "Tom &amp; Jerry &quot;Red&quot;",
      "Tom and Jerry &quot;Blue&quot;",
      'Tom<del class="differ"> and Jerry</del> &<ins class="differ">amp; Jerry &</ins>quot;' \
        '<del class="differ">Blue</del><ins class="differ">Red</ins>&quot;'
    ],
    "a change inside an entity" => [
      "edition&quot; ink",
      "edition,&quot; ink",
      'edition<del class="differ">,&</del><ins class="differ">&</ins>quot; ink'
    ],
    "CJK text" => [
      "春日纪 Spring",
      "春日纪Spring",
      '<del class="differ">春日纪Spring</del><ins class="differ">春日纪 Spring</ins>'
    ],
    "an empty new text" => ["", "Old ink", '<del class="differ">Old ink</del>'],
    "an empty old text" => ["New ink", "", '<ins class="differ">New ink</ins>'],
    "two empty texts" => ["", "", ""]
  }.each do |name, (new_text, old_text, expected)|
    it "renders #{name} like differ" do
      expect(diff(new_text, old_text)).to eq(expected)
    end
  end

  it "treats nil as an empty text" do
    expect(diff(nil, "Old ink")).to eq('<del class="differ">Old ink</del>')
  end

  describe "size limit" do
    let(:at_limit) { (["x"] * 1_500).join(" ") }
    let(:over_limit) { (["x"] * 1_501).join(" ") }

    it "diffs texts with up to 3,000 tokens" do
      expect(at_limit.split(/\b/).length).to eq(2_999)

      expect(diff(at_limit.sub(/x\z/, "y"), at_limit)).to eq(
        "#{at_limit.chop}<del class=\"differ\">x</del><ins class=\"differ\">y</ins>"
      )
    end

    it "does not diff when the new text has more than 3,000 tokens" do
      expect(over_limit.split(/\b/).length).to eq(3_001)

      expect(diff(over_limit, "x")).to eq('<em class="text-muted">Too long to compare.</em>')
    end

    it "does not diff when the old text has more than 3,000 tokens" do
      expect(diff("x", over_limit)).to eq('<em class="text-muted">Too long to compare.</em>')
    end

    it "diffs long texts with few tokens" do
      long_word = "a" * 5_000

      expect(diff("#{long_word} ink", "#{long_word} pen")).to eq(
        "#{long_word} <del class=\"differ\">pen</del><ins class=\"differ\">ink</ins>"
      )
    end
  end

  it "returns the same HTML when called twice" do
    word_diff = described_class.new("A blue", "A blue ink pen")

    expect(word_diff.html).to eq('A blue<del class="differ"> ink pen</del>')
    expect(word_diff.html).to eq('A blue<del class="differ"> ink pen</del>')
  end
end
