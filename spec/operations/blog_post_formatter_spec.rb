require "rails_helper"

describe BlogPostFormatter do
  def render(source)
    described_class.render(source).to_s
  end

  it "keeps class and id attributes" do
    output = render('<p><span class="multi" id="intro">x</span></p>')
    expect(output).to include('<span class="multi" id="intro">x</span>')
  end

  it "keeps images" do
    output = render("![Bottle](https://fpc.nyc3.cdn.digitaloceanspaces.com/bottle.jpg)")
    expect(output).to include('<img src="https://fpc.nyc3.cdn.digitaloceanspaces.com/bottle.jpg"')
  end

  it "still strips inline styles" do
    output = render('<p style="position:fixed">x</p>')
    expect(output).not_to include("style=")
  end

  it "still strips iframes" do
    output = render('<iframe src="https://www.youtube.com/embed/abc"></iframe>')
    expect(output).not_to include("<iframe")
  end
end
