module Pens
  class UpdateModelVariant
    include Sidekiq::Worker

    def perform(model_variant_id)
      self.model_variant = Pens::ModelVariant.find(model_variant_id)
      return if model_variant.collected_pens.empty?

      update_attributes!
      Pens::AssignModelMicroCluster.perform_async(model_variant_id)
      update_embedding!
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
      attr_values =
        model_variant.collected_pens.map { |cp| cp.send(attr) }.find_all { |v| v.present? }.tally
      return "" if attr_values.empty?

      # When there's more than one value that is the most common, pick the longest
      # name to avoid duplicates more often.
      max_count = attr_values.values.max
      max_attrs = attr_values.find_all { |_k, v| v == max_count }.to_h
      max_attrs.max_by { |k, v| v + k.to_s.length }.first || ""
    end

    def update_embedding!
      embedding = model_variant.pen_embedding || model_variant.build_pen_embedding
      embedding.update!(content: model_variant.name)
    end
  end
end
