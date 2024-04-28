require "rails_helper"

describe RefreshPens do
  it "schedules jobs for every 100 pens" do
    pens = create_list(:collected_pen, 150)
    expect { subject.perform }.to change(described_class.jobs, :length).by(2)
    j1 = described_class.jobs.first
    expect(j1["args"].first.length).to eq(100)
    j2 = described_class.jobs.last
    expect(j2["args"].first.length).to eq(50)
  end

  it "runs SaveCollectedPen for each supplied id" do
    pen = create(:collected_pen)
    expect(SaveCollectedPen).to receive(:new).with(pen, {}).and_call_original
    subject.perform([pen.id])
  end
end
