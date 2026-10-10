module Bench
  module Suggester
    class Store
      RUN_NAME = /\A[a-z0-9][a-z0-9_.-]*\z/

      class InvalidRunName < StandardError
      end

      attr_accessor :root

      def initialize(root = Bench::Suggester.default_root)
        self.root = Pathname.new(root)
      end

      def write_export(export)
        write_json("cases.json", export.cases.map(&:to_h))
        write_json("dropped.json", export.dropped)
      end

      def cases
        read_json("cases.json").map { |hash| BenchCase.from_h(hash) }
      end

      def labels
        Label.load_file(path("labels.yml"))
      end

      def extractor_labels
        ExtractorLabel.load_file(path("extractor_labels.yml"))
      end

      def write_label_template(cases)
        existing = labels_file? ? (YAML.safe_load_file(path("labels.yml")) || {}) : {}
        existing = existing.transform_keys(&:to_s)
        added = cases.map(&:id) - existing.keys
        template = existing.merge(added.to_h { |id| [id, Label.from_h(id, {}).to_h] })
        write("labels.yml", template.to_yaml)
        added.size
      end

      def write_results(name, payload)
        write_json("results/#{run_name(name)}.json", payload)
      end

      def results(name)
        read_json("results/#{run_name(name)}.json")
      end

      def write_files(directory, files)
        files.each { |file_name, content| write("#{directory}/#{file_name}", content) }
      end

      def read_json(relative)
        JSON.parse(File.read(path(relative)))
      end

      def path(relative)
        root.join(relative)
      end

      private

      def labels_file?
        File.exist?(path("labels.yml"))
      end

      def run_name(name)
        raise InvalidRunName, "invalid run name #{name.inspect}" unless name.to_s.match?(RUN_NAME)

        name
      end

      def write_json(relative, payload)
        write(relative, JSON.pretty_generate(payload))
      end

      def write(relative, content)
        FileUtils.mkdir_p(path(relative).dirname)
        File.write(path(relative), content)
      end
    end
  end
end
