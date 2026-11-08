module Bench
  module Clusterer
    class Store
      RUN_NAME = /\A[a-z0-9][a-z0-9_.-]*\z/

      class InvalidRunName < StandardError
      end

      attr_accessor :root

      def initialize(root = Bench::Clusterer.default_root)
        self.root = Pathname.new(root)
      end

      def write_cases(cases)
        write_json("cases.json", cases.map(&:to_h))
      end

      def cases
        read_json("cases.json").map { |hash| BenchCase.from_h(hash) }
      end

      def write_results(name, results)
        write_json("results/#{run_name(name)}.json", results)
      end

      def results(name)
        read_json("results/#{run_name(name)}.json")
      end

      def path(relative)
        root.join(relative)
      end

      private

      def run_name(name)
        raise InvalidRunName, "invalid run name #{name.inspect}" unless name.to_s.match?(RUN_NAME)

        name
      end

      def read_json(relative)
        JSON.parse(File.read(path(relative)))
      end

      def write_json(relative, payload)
        FileUtils.mkdir_p(path(relative).dirname)
        File.write(path(relative), JSON.pretty_generate(payload))
      end
    end
  end
end
