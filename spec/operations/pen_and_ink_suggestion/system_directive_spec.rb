require "rails_helper"

RSpec.describe "PenAndInkSuggestion::PickPrompt::SYSTEM_DIRECTIVE" do
  let(:directive) { PenAndInkSuggestion::PickPrompt::SYSTEM_DIRECTIVE }
  let(:width_lines) do
    directive.lines.filter_map do |line|
      match = line.chomp.match(/\A- W(\d) (\S+) \(([^)]*)\): (.*)\z/)
      [match[1].to_i, match[2], match[3], match[4]] if match
    end
  end
  let(:specialist_nibs) do
    {
      1 => {
        "needlepoint" => [["Needlepoint"]],
        "Pilot PO (posting)" => [%w[PO Pilot]]
      },
      2 => {
        "Pilot FA (flex)" => [%w[FA Pilot]]
      },
      3 => {
      },
      4 => {
        "Pilot WA" => [%w[WA Pilot]],
        "SU" => [%w[SU Pilot]],
        "CM" => [%w[CM Pilot]],
        "Journaler" => [%w[Journaler Esterbrook]]
      },
      5 => {
        "Zoom" => [%w[Zoom Sailor]],
        "Music" => [%w[Music Sailor]],
        "fude (nominal)" => [%w[Fude Sailor]]
      },
      6 => {
        "1.0-1.2 mm stubs/italics" => [["1.0 stub"], ["1.1 stub"], ["1.2 italic"]],
        "Pilot S (Signature)" => [%w[S Pilot]]
      },
      7 => {
        "stubs from 1.3 mm (1.5, 1.9)" => [["1.3 stub"], ["1.5 stub"], ["1.9 stub"]],
        "Pilot Parallel" => [%w[1.5 Pilot Parallel], %w[3.8 Pilot Parallel]]
      }
    }
  end

  def split(text)
    text.to_s.split(/[;,]\s*(?![^(]*\))/).map(&:strip).reject(&:empty?)
  end

  def grades(text)
    split(text.to_s.tr("/", ",")).map { |grade| grade.sub(/\s*\(.*\)\z/, "") }
  end

  def segments(rest)
    western, japanese, specialist = nil
    rest
      .split(/;\s*/)
      .each do |segment|
        if segment.start_with?("Western ")
          western = segment.delete_prefix("Western ")
        elsif segment.start_with?("Japanese ")
          japanese = segment.delete_prefix("Japanese ")
        else
          specialist = [specialist, segment].compact.join("; ")
        end
      end
    [western, japanese, specialist]
  end

  def width_of(nib, brand = nil, model = nil)
    NibProfile.parse(nib, brand:, model:).width
  end

  it "has one line per width class" do
    expect(width_lines.map(&:first)).to eq((1..7).to_a)
  end

  it "states the NibProfile class limits" do
    limits = NibProfile::WIDTH_CLASS_LIMITS
    expected =
      (1..7).to_h do |width|
        text =
          if width == 1
            "<=#{limits[1]} mm"
          elsif width == 7
            ">#{limits[6]}"
          else
            "#{limits[width - 1]}-#{limits[width]}"
          end
        [width, text]
      end

    expect(width_lines.to_h { |width, _label, range, _rest| [width, range] }).to eq(expected)
  end

  it "lists exactly the Western grades NibProfile puts in each class" do
    western_grades = NibProfile::GRADE_WIDTHS.except("C")
    width_lines.each do |width, _label, _range, rest|
      listed = grades(segments(rest)[0]).map { |grade| grade == "3B" ? "BBB" : grade }
      expected =
        western_grades.keys.select do |grade|
          NibProfile.width_class(western_grades[grade][:western]) == width
        end

      expect(listed.uniq).to match_array(expected), "W#{width}"
      listed.each { |grade| expect(width_of(grade, "Lamy")).to eq(width), "W#{width} #{grade}" }
    end
  end

  it "lists every Japanese grade NibProfile puts in each class, and only grades of that class" do
    width_lines.each do |width, _label, _range, rest|
      listed = grades(segments(rest)[1])
      expected =
        NibProfile::GRADE_WIDTHS.keys.select do |grade|
          NibProfile.width_class(NibProfile::GRADE_WIDTHS[grade][:japanese]) == width
        end

      expect(listed & expected).to match_array(expected), "W#{width}"
      listed.each { |grade| expect(width_of(grade, "Sailor")).to eq(width), "W#{width} #{grade}" }
    end
  end

  it "lists specialist nibs and codes in the class NibProfile gives them" do
    width_lines.each do |width, _label, _range, rest|
      listed = split(segments(rest)[2])

      expect(listed).to match_array(specialist_nibs.fetch(width).keys), "W#{width}"
      specialist_nibs
        .fetch(width)
        .each do |text, examples|
          examples.each do |nib, brand, model|
            expect(width_of(nib, brand, model)).to eq(width), "W#{width} #{text}: #{nib}"
          end
        end
    end
  end

  it "uses the reference's labels for the classes" do
    expect(width_lines.map { |_width, label| label }).to eq(%w[XXF EF F M B BB BBB+])
  end

  it "matches the width-class lines of the nib reference's table" do
    reference = Rails.root.join("docs/nib-reference.md").read
    rows =
      reference.lines.filter_map do |line|
        cells = line.split("|").map(&:strip)
        cells[1..6] if cells[1].to_s.match?(/\AW\d\z/)
      end

    rows.each do |klass, label, _mm, western, japanese, specialist|
      line = directive.lines.find { |candidate| candidate.start_with?("- #{klass} #{label} (") }

      expect(line).to be_present, klass
      grades(western).each { |grade| expect(line).to include(grade), "#{klass} #{grade}" }
      grades(japanese)
        .reject { |grade| grade == "—" }
        .each { |grade| expect(line).to include(grade), "#{klass} #{grade}" }
      split(specialist.tr("–", "-"))
        .reject { |item| item == "—" }
        .each { |item| expect(line).to include(item), "#{klass} #{item}" }
    end
  end
end
