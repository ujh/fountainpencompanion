RubyLLM.configure do |config|
  # Opt into the new acts_as API. The app uses RubyLLM::Chat directly and no
  # acts_as_* ActiveRecord models, so this only silences the legacy deprecation
  # warning without changing behavior. Required before RubyLLM 2.0.
  config.use_new_acts_as = true
end

RubyLLM::Tool.prepend(
  Module.new do
    def name
      klass_name = self.class.name.demodulize
      normalized = klass_name.to_s.dup.force_encoding("UTF-8").unicode_normalize(:nfkd)
      normalized
        .encode("ASCII", replace: "")
        .gsub(/[^a-zA-Z0-9_-]/, "-")
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .downcase
        .delete_suffix("_tool")
    end
  end
)
