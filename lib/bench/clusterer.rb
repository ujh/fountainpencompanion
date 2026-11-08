module Bench
  module Clusterer
    KINDS = %w[assign ignore create round1].freeze

    def self.default_root
      ENV.fetch("BENCH_DIR") { Rails.root.join("tmp/bench/clusterer").to_s }
    end

    def self.parse_time(value, name:)
      return if value.blank?

      Time.zone.parse(value) || raise(ArgumentError, "#{name} is not a date: #{value.inspect}")
    end
  end
end

require_relative "clusterer/bench_case"
require_relative "clusterer/source"
require_relative "clusterer/case_exporter"
require_relative "clusterer/replayer"
require_relative "clusterer/report"
require_relative "clusterer/store"
