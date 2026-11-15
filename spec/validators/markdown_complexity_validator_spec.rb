require "rails_helper"

describe MarkdownComplexityValidator do
  subject { model_class.new }

  let(:model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes

      def self.name = "DescribedThing"

      attribute :description, :string
      validates :description, markdown_complexity: true
    end
  end

  it "accepts a blank text" do
    expect(subject).to be_valid
  end

  it "accepts links and brackets nested five deep" do
    subject.description = "See [the review](https://example.com) and [[[[[five]]]]] [a] [b]"
    expect(subject).to be_valid
  end

  it "rejects brackets nested six deep" do
    subject.description = "[[[[[[six]]]]]]"
    expect(subject).to be_invalid
    expect(subject.errors[:description]).to eq(["has too many nested brackets"])
  end

  it "counts brackets that are never closed" do
    subject.description = "[a [b [c [d [e [f"
    expect(subject).to be_invalid
  end

  it "rejects a text that takes too long to render" do
    stub_const("FpcFormatter::RENDER_TIMEOUT", 0.05)
    subject.description = ("**a " * 8 + "[x]( " * 1_000)[0, 5_000]

    expect(subject).to be_invalid
    expect(subject.errors[:description]).to eq(["is too complex to display"])
  end

  it "accepts a text the renderer shows as plain text" do
    subject.description = "<div>" * 1_000
    expect(subject).to be_valid
  end
end
