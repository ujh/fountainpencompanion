require 'rails_helper'

describe Ink do
  it 'requires a name' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:name)
  end

  it 'requires a manufacturer' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:manufacturer)
  end

  it 'requires a valid manufacturer' do
    subject.manufacturer = Manufacturer.new
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:manufacturer)
  end
end
