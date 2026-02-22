class InkReviewSerializer
  include JSONAPI::Serializer

  set_type :ink_review

  attribute :title
  attribute :url
  attribute :image
  attribute :author
  attribute :description
  attribute :approved_at
end
