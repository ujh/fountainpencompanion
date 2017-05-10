require 'rails_helper'

describe Manufacturer do
  it 'requires a name' do
    expect(subject).to_not be_valid
    expect(subject.errors).to include(:name)
  end
end
