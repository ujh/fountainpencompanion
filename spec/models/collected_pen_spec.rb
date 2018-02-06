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

  describe '#name' do
    it 'combines brand and model' do
      subject.brand = 'brand'
      subject.model = 'model'
      expect(subject.name).to eq('brand model')
    end
  end

  describe '#search' do
    fixtures :collected_pens

    it 'finds matching entries by substring search' do
      expect(described_class.search(:brand, 'P')).to eq(["Pilot", "Platinum"])
    end
  end
end
