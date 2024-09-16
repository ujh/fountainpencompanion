require "rails_helper"

describe AfterUserSaved do
  it "marks user for review if it contains URL" do
    user = create(:user, blurb: "http://www.ruby.com")
    described_class.new.perform(user.id)
    user.reload
    expect(user.review_blurb).to be true
    expect(SpamClassifier.jobs.count).to eq(1)
  end

  it "marks user if review contains Markdown link" do
    user = create(:user, blurb: "[Ruby](ruby.com)")
    described_class.new.perform(user.id)
    user.reload
    expect(user.review_blurb).to be true
    expect(SpamClassifier.jobs.count).to eq(1)
  end

  it "marks user for review if it contains URL without protocol" do
    user = create(:user, blurb: "www.ruby.com")
    described_class.new.perform(user.id)
    user.reload
    expect(user.review_blurb).to be true
    expect(SpamClassifier.jobs.count).to eq(1)
  end

  it "marks user as not for review if it does not contain a link" do
    user = create(:user, blurb: "random text")
    described_class.new.perform(user.id)
    user.reload
    expect(user.review_blurb).to be false
    expect(SpamClassifier.jobs.count).to eq(0)
  end
end
