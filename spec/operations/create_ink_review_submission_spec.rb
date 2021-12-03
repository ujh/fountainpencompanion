require 'rails_helper'

describe CreateInkReviewSubmission do
  let(:user) { create(:user) }
  let(:macro_cluster) { create(:macro_cluster) }
  let(:url) { 'http://example.com' }

  subject { described_class.new(user: user, macro_cluster: macro_cluster, url: url) }

  it 'saves the submission' do
    expect do
      subject.perform
    end.to change(InkReviewSubmission, :count).by(1)
  end

  it 'sets the correct attributes' do
    submission = subject.perform
    expect(submission.user).to eq(user)
    expect(submission.macro_cluster).to eq(macro_cluster)
    expect(submission.url).to eq('http://example.com')
  end

  it 'schedules the processing job' do
    expect do
      subject.perform
    end.to change(ProcessInkReviewSubmission.jobs, :count).by(1)
  end

  it 'passes the submission id to the processing job' do
    submission = subject.perform
    job = ProcessInkReviewSubmission.jobs.first
    expect(job['args']).to eq([submission.id])
  end

  it 'does not schedule the processing job if the submission cannot be saved' do
    expect do
      described_class.new(user: nil, macro_cluster: nil, url: nil).perform
    end.not_to change(ProcessInkReviewSubmission.jobs, :count)
  end
end
