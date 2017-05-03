class CollectedInk < ApplicationRecord
  validates :ink, associated: true
  validates :kind, inclusion: { in: %w(bottle sample cartridge), allow_nil: true }

  belongs_to :ink
  belongs_to :user

  def self.build(params = {})
    manufacturer = Manufacturer.find_or_initialize_by(name: params[:manufacturer_name])
    if manufacturer.new_record?
      ink = Ink.new(name: params[:name], manufacturer: manufacturer)
    else
      ink = Ink.find_or_initialize_by(name: params[:name], manufacturer_id: manufacturer.id)
    end
    new(ink: ink)
  end

  def manufacturer_name
    manufacturer.name
  end

  def name
    ink.name
  end

  private

  def manufacturer
    ink.manufacturer
  end
end
