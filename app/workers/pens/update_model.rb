module Pens
  class UpdateModel
    include Sidekiq::Worker

    def perform(model_id)
      self.model = Pens::Model.find(model_id)
      return if model.collected_pens.empty?

      update_attributes!
      Pens::AssignBrand.perform_async(model_id)
      update_embedding!
    end

    private

    attr_accessor :model

    def update_attributes!
      %i[brand model].each { |attr| model.send("#{attr}=", best_attr_value(attr)) }
      model.save
    end

    def best_attr_value(attr)
      attr_values = model.collected_pens.map { |cp| cp.send(attr) }.find_all { |v| v.present? }
      return "" if attr_values.empty?
      attr_values.tally.max_by { |_k, v| v }.first || ""
    end

    def update_embedding!
      embedding = model.pen_embedding || model.build_pen_embedding
      embedding.update!(content: model.name)
    end
  end
end
