class InkDetailSerializer
  include JSONAPI::Serializer

  set_type :macro_cluster

  has_many :approved_ink_reviews, serializer: InkReviewSerializer

  attribute :brand_name
  attribute :line_name
  attribute :ink_name
  attribute :color
  attribute :description
  attribute :public_collected_inks_count
  attribute :tags
  attribute :colors do |object|
    object.collected_inks.pluck(:color).uniq.reject(&:blank?)
  end
  attribute :all_names do |object|
    names = object.all_names
    object.all_names_as_elements.map do |ink|
      {
        brand_name: ink[:brand_name],
        line_name: ink[:line_name],
        ink_name: ink[:ink_name],
        collected_inks_count:
          names
            .find { |n| n.slice(:brand_name, :line_name, :ink_name) == ink }
            &.collected_inks_count || 0
      }
    end
  end
end
