require 'rails_helper'

describe UpdateInkBrand do

  it 'creates a new ink brand if none exist'
  it 'uses an existing ink brand if it matches'
  it 'uses a similar ink brand if it exists'
  it 'uses the closest match if multiple exist'
  it 'creates a new ink brand if existing ones are too dissimilar'
end
