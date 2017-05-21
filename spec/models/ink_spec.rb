require 'rails_helper'

describe Ink do
  it 'requires a name' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:name)
  end

  it 'requires a brand' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:brand)
  end

  it 'requires a valid brand' do
    subject.brand = Brand.new
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:brand)
  end
end
