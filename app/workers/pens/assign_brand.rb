module Pens
  class AssignBrand
    include Sidekiq::Worker

    def perform(model_id)
      self.model = Pens::Model.find_by(id: model_id)
      return unless model

      assign_brand!
    end

    private

    attr_accessor :model

    def assign_brand!
      return if model.pen_brand

      Pens::Brand.find_each do |brand|
        model.update!(pen_brand: brand) if brand.names.include?(model.brand)
      end
    end
  end
end
