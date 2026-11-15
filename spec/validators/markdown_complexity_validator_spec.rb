require "rails_helper"

describe MarkdownComplexityValidator do
  include SlowMarkdownHelpers

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
    make_markdown_slow
    subject.description = SlowMarkdownHelpers::SLOW_MARKDOWN

    expect(subject).to be_invalid
    expect(subject.errors[:description]).to eq(["is too complex to display"])
  end

  it "accepts a text the renderer shows as plain text" do
    subject.description = "<div>" * 1_000
    expect(subject).to be_valid
  end

  it "skips the render check when the text already has an error" do
    limited_class =
      Class.new(model_class) do
        def self.name = "LimitedThing"

        clear_validators!
        validates :description, length: { maximum: 10 }, markdown_complexity: true
      end
    thing = limited_class.new(description: "*" * 11)

    expect(FpcFormatter).not_to receive(:too_slow_to_render?)
    expect(thing).to be_invalid
    expect(thing.errors[:description]).to eq(["is too long (maximum is 10 characters)"])
  end
end
