class SerializableUser < JSONAPI::Serializable::Resource
  type 'user'
  attribute :name

  has_many :collected_inks do
    data do
      @object.public_inks.includes(:micro_cluster)
    end
  end

end
