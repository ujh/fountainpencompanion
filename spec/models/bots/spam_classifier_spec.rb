require "rails_helper"

describe Bots::SpamClassifier do
  let(:user) { create(:user) }

  subject { described_class.new(user) }

  before do
    create(:user, spam: true)
    create(:user, spam: false, blurb: "blurb")
  end

  it 'returns true if text response is "spam"' do
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json"
      },
      body: { "choices" => [{ "message" => { "content" => "spam" } }] }.to_json
    )
    expect(subject.run).to eq true
  end

  it 'returns false if text response is "normal"' do
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json"
      },
      body: {
        "choices" => [{ "message" => { "content" => "normal" } }]
      }.to_json
    )
    expect(subject.run).to eq false
  end

  it "returns false if text contains word normal" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json"
      },
      body: {
        "choices" => [{ "message" => { "content" => "spam but also normal" } }]
      }.to_json
    )
    expect(subject.run).to eq false
  end
end
