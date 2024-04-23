module Pens
  class UpdateModelVariant
    include Sidekiq::Worker

    def perform(model_variant_id)
      self.model_variant = Pens::ModelVariant.find(model_variant_id)
      return if model_variant.collected_pens.empty?

      update_attributes!
    end

    private

    attr_accessor :model_variant

    def update_attributes!
      %i[brand model color material trim_color filling_system].each do |attr|
        model_variant.send("#{attr}=", best_attr_value(attr))
      end
      model_variant.save
    end

    def best_attr_value(attr)
      attr_values = model_variant.collected_pens.map { |cp| cp.send(attr) }
      attr_values.tally.max_by { |_k, v| v }.first || ""
    end
  end
end
