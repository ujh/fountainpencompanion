class SerializableBrand < JSONAPI::Serializable::Resource
  id { @object.simplified_brand_name }
  type 'brands'
  attribute :popular_name
end
