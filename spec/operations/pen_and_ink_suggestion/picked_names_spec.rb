require "rails_helper"

RSpec.describe PenAndInkSuggestion::PickedNames do
  let(:pen) do
    build(
      :collected_pen,
      brand: "Corvid",
      model: "Heron Slim",
      color: "Moss Lagoon",
      material: "Ebonite",
      nib: "Fine"
    )
  end
  let(:ink) do
    build(
      :collected_ink,
      brand_name: "Jules Quillworth",
      line_name: "Tides",
      ink_name: "Harbour Fog"
    )
  end

  subject(:picked) { described_class.new(pen, ink) }

  it "matches a mention whose words all name the picked pen's brand, model or colour" do
    expect(picked.matches?("Corvid Heron")).to be(true)
    expect(picked.matches?("moss lagoon")).to be(true)
    expect(picked.matches?("my Moss Lagoon Corvid")).to be(true)
    expect(picked.matches?("CORVID")).to be(true)
  end

  it "matches a mention whose words all name the picked ink's brand, line or name" do
    expect(picked.matches?("jules quillworth")).to be(true)
    expect(picked.matches?("Tides Harbour Fog")).to be(true)
    expect(picked.matches?("Quillworth ink")).to be(true)
  end

  it "matches a one-letter initial next to a full word of the same item" do
    expect(picked.matches?("j quillworth")).to be(true)
    expect(picked.matches?("J.Quillworth")).to be(true)
    expect(picked.matches?("C Heron")).to be(true)
  end

  it "doesn't match an initial alone, an initial of no word, a nib grade or a digit" do
    expect(picked.matches?("J.")).to be(false)
    expect(picked.matches?("Corvid M")).to be(false)
    expect(picked.matches?("x quillworth")).to be(false)
    expect(picked.matches?("Corvid Heron 2")).to be(false)
  end

  it "doesn't match a mention with any word the picked item lacks" do
    expect(picked.matches?("Corvid Egret")).to be(false)
    expect(picked.matches?("Harbor Fog")).to be(false)
  end

  it "doesn't match words spread over the picked pen and the picked ink" do
    expect(picked.matches?("Corvid Harbour Fog")).to be(false)
  end

  it "doesn't match on the pen's material or nib" do
    expect(picked.matches?("Corvid Ebonite")).to be(false)
    expect(picked.matches?("Heron Fine")).to be(false)
  end

  it "doesn't match a mention made only of filler or generic words" do
    expect(picked.matches?("my pen")).to be(false)
    expect(picked.matches?("")).to be(false)
  end

  it "matches nothing without picked items" do
    expect(described_class.new(nil, nil).matches?("Corvid")).to be(false)
  end
end
