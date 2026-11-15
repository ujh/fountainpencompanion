require "rails_helper"

describe MarkdownNestingValidator do
  subject { model_class.new }

  let(:model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes

      def self.name = "DescribedThing"

      attribute :description, :string
      validates :description, markdown_nesting: true
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
end
