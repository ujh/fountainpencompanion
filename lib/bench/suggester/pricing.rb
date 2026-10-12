module Bench
  module Suggester
    module Pricing
      USD_PER_MILLION_TOKENS = {
        "gpt-4.1" => {
          input: 2.00,
          cached_input: 0.50,
          output: 8.00
        },
        "gpt-4.1-mini" => {
          input: 0.40,
          cached_input: 0.10,
          output: 1.60
        },
        "gpt-4.1-nano" => {
          input: 0.10,
          cached_input: 0.025,
          output: 0.40
        },
        "gpt-5-mini" => {
          input: 0.25,
          cached_input: 0.025,
          output: 2.00
        },
        "gpt-5-nano" => {
          input: 0.05,
          cached_input: 0.005,
          output: 0.40
        },
        "gpt-5.4-mini" => {
          input: 0.75,
          cached_input: 0.075,
          output: 4.50
        },
        "gpt-5.4-nano" => {
          input: 0.20,
          cached_input: 0.02,
          output: 1.25
        },
        "gpt-5.6-luna" => {
          input: 0.20,
          cached_input: 0.02,
          cache_write: 0.25,
          output: 1.20
        },
        "gpt-6-luna" => {
          input: 0.10,
          cached_input: 0.01,
          cache_write: 0.125,
          output: 0.50
        },
        "gpt-6-sol" => {
          input: 2.00,
          cached_input: 0.20,
          cache_write: 2.50,
          output: 10.00
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

      TOKEN_KEYS = %w[prompt_tokens cached_tokens cache_write_tokens completion_tokens].freeze

      def self.cost(usage, cache_discount: true)
        usage = usage.to_h.stringify_keys
        return 0.0 if TOKEN_KEYS.all? { |key| usage[key].to_i.zero? }

        price = price_for(usage["model"])
        return unless price

        write_price = price.fetch(:cache_write, price[:input])
        cached_price = cache_discount ? price[:cached_input] : write_price
        (
          usage["prompt_tokens"].to_i * price[:input] + usage["cached_tokens"].to_i * cached_price +
            usage["cache_write_tokens"].to_i * write_price +
            usage["completion_tokens"].to_i * price[:output]
        ) / 1_000_000.0
      end

      def self.total_cost(usages, cache_discount: true)
        costs = usages.map { |usage| cost(usage, cache_discount:) }
        costs.sum if costs.any? && costs.none?(&:nil?)
      end
    end
  end
end
