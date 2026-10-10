module Bench
  module Suggester
    module Pricing
      USD_PER_MILLION_TOKENS = {
        "gpt-4.1" => {
          input: 2.00,
          output: 8.00
        },
        "gpt-4.1-mini" => {
          input: 0.40,
          output: 1.60
        },
        "gpt-4.1-nano" => {
          input: 0.10,
          output: 0.40
        }
      }.freeze

      def self.price_for(model)
        model = model.to_s
        key =
          USD_PER_MILLION_TOKENS
            .keys
            .sort_by { |name| -name.length }
            .find { |name| model == name || model.start_with?("#{name}-") }
        USD_PER_MILLION_TOKENS[key] if key
      end

      CACHED_INPUT_SHARE = 0.25
      TOKEN_KEYS = %w[prompt_tokens cached_tokens completion_tokens].freeze

      def self.cost(usage, cache_discount: true)
        usage = usage.to_h.stringify_keys
        return 0.0 if TOKEN_KEYS.all? { |key| usage[key].to_i.zero? }

        price = price_for(usage["model"])
        return unless price

        cached_share = cache_discount ? CACHED_INPUT_SHARE : 1.0
        input = usage["prompt_tokens"].to_i + usage["cached_tokens"].to_i * cached_share
        (input * price[:input] + usage["completion_tokens"].to_i * price[:output]) / 1_000_000.0
      end

      def self.total_cost(usages, cache_discount: true)
        costs = usages.map { |usage| cost(usage, cache_discount:) }
        costs.sum if costs.any? && costs.none?(&:nil?)
      end
    end
  end
end
