require 'rails_helper'

describe CollectedInk do
  it 'requires an associated user' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:user)
  end

  it 'requires an ink name' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:ink_name)
  end

  it 'requires a brand name' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:brand_name)
  end
end
