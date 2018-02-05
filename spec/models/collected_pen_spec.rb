require 'rails_helper'

describe CollectedPen do
  it 'requires an associated user' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:user)
  end

  it 'requires an brand' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:brand)
  end

  it 'requires a model' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:model)
  end
end
