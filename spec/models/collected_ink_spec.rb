require 'rails_helper'

describe CollectedInk do
  it 'requires an associated user' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:user)
  end

  it 'requires an associated ink' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:ink)
  end

  it 'requires a valid ink' do
    subject.ink = Ink.new
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:ink)
  end
end
