class CollectedInk < ApplicationRecord

  KINDS = %w(bottle sample cartridge)

  validates :ink, associated: true
  validates :kind, inclusion: { in: KINDS, allow_blank: true }
  validates :brand_name, presence: true
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

  def brand_name
    brand&.name
  end

  def ink_name
    ink&.name
  end

  def name
    "#{brand_name} #{ink_name}"
  end

  def update_from_params(params = {})
    self.kind = params[:kind] if params[:kind]
    if params[:brand_name]
      brand = Brand.find_or_initialize_by(name: params[:brand_name])
    else
      brand = self.brand || Brand.new
    end
    ink_name = (params[:ink_name] || self.ink_name)
    if brand.new_record?
      ink = Ink.new(name: ink_name, brand: brand)
    else
      ink = Ink.find_or_initialize_by(name: ink_name, brand_id: brand.id)
    end
    self.ink = ink
    self
  end

  protected

  def brand
    ink&.brand
  end
end
