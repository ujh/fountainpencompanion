require_relative "../bench_helper"

RSpec.describe Bench::Suggester::Checks::NamedTargets do
  def check(label, extra_data)
    described_class.new(label: Bench::Suggester::Label.from_h(1, label), extra_data:).call
  end

  it "hits when the pick is one of the labelled targets" do
    result = check({ "named_pens" => [1, 2], "named_inks" => [5] }, { "pen" => 2, "ink" => 6 })

    expect(result).to eq("pen_hit" => true, "ink_hit" => false)
  end

  it "misses when there is no pick" do
    expect(check({ "named_pens" => [1] }, { "message" => "Sorry" })).to eq(
      "pen_hit" => false,
      "ink_hit" => nil
    )
  end

  it "is nil for a side without targets" do
    expect(check({}, { "pen" => 1, "ink" => 2 })).to eq("pen_hit" => nil, "ink_hit" => nil)
  end
end
