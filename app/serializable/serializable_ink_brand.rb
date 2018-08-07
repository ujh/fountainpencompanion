class SerializableInkBrand < JSONAPI::Serializable::Resource
  type 'brands'
  attribute :popular_name
end
