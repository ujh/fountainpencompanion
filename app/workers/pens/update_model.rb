module Pens
  class UpdateModel
    include Sidekiq::Worker

    def perform(model_id)
      self.model = Pens::Model.find(model_id)
      return if model.model_variants.empty?

      update_attributes!
    end

    private

    attr_accessor :model

    def update_attributes!
      %i[brand model].each do |attr|
        model.send("#{attr}=", best_attr_value(attr))
      end
      model.save
    end

    def best_attr_value(attr)
      attr_values = model.collected_pens.map { |cp| cp.send(attr) }
      attr_values.tally.max_by { |_k, v| v }.first || ""
    end
  end
end
