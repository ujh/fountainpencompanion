class SafeApipieStaticDispatcher
  GLOB_CHARACTERS = /[*?\[\]{}\\]/

  attr_accessor :app, :dispatcher

  def initialize(app, path)
    self.app = app
    self.dispatcher = Apipie::StaticDispatcher.new(app, path)
  end

  def call(env)
    docs_asset_request?(env) ? dispatcher.call(env) : app.call(env)
  end

  private

  def docs_asset_request?(env)
    %w[GET HEAD].include?(env["REQUEST_METHOD"]) && plain_docs_path?(env["PATH_INFO"].to_s)
  end

  def plain_docs_path?(path)
    path.start_with?("#{Apipie.configuration.doc_base_url}/") &&
      !Rack::Utils.unescape(path).match?(GLOB_CHARACTERS)
  rescue ArgumentError
    false
  end
end
