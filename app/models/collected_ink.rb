class CollectedInk < ApplicationRecord

  KINDS = %w(bottle sample cartridge)

  validates :ink, associated: true
  validates :kind, inclusion: { in: KINDS, allow_blank: true }
  validates :manufacturer_name, presence: true
  validates :ink_name, presence: true

  belongs_to :ink
  belongs_to :user

  def self.build(params = {})
    record = new
    record.update_from_params(params)
    record
  end

  def self.update(params = {})
    record = find(params[:id])
    record.update_from_params(params[:collected_ink])
    record
  end

  def manufacturer_name
    manufacturer&.name
  end

  def ink_name
    ink&.name
  end

  def name
    "#{manufacturer_name} #{ink_name}"
  end

  def update_from_params(params = {})
    self.kind = params[:kind] if params[:kind]
    if params[:manufacturer_name]
      manufacturer = Manufacturer.find_or_initialize_by(name: params[:manufacturer_name])
    else
      manufacturer = self.manufacturer || Manufacturer.new
    end
    ink_name = (params[:ink_name] || self.ink_name)
    if manufacturer.new_record?
      ink = Ink.new(name: ink_name, manufacturer: manufacturer)
    else
      ink = Ink.find_or_initialize_by(name: ink_name, manufacturer_id: manufacturer.id)
    end
    self.ink = ink
    self
  end

  protected

  def manufacturer
    ink&.manufacturer
  end
end
