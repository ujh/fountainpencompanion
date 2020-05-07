require 'rails_helper'

describe SaveCollectedInk do

  def add!(params)
    ci = CollectedInk.new(user: create(:user))
    SaveCollectedInk.new(ci, params).perform
    ci
  end

  def default!(params = {})
    add!({
      brand_name: 'Pilot', line_name: 'Iroshizuku', ink_name: 'Kon-Peki'
    }.merge(params))
  end

  it 'schedules a AssignMicroCluster job' do
    expect do
      default!
    end.to change { AssignMicroCluster.jobs.size }.by(1)
  end
end
