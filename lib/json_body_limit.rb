class JsonBodyLimit
  MAX_BYTES = 1.megabyte

  attr_accessor :app

  def initialize(app)
    self.app = app
  end

  def call(env)
    media_type = parsed_media_type(env)
    return app.call(env) unless media_type && too_large?(env)

    body = { errors: [{ status: "413", title: "Payload Too Large" }] }.to_json
    [413, { "content-type" => media_type.to_s }, [body]]
  end

  private

  def parsed_media_type(env)
    media_type = ActionDispatch::Request.new(env).content_mime_type
    media_type if ActionDispatch::Request.parameter_parsers.key?(media_type&.symbol)
  rescue ActionDispatch::Http::MimeNegotiation::InvalidType
    nil
  end

  def too_large?(env)
    if env["CONTENT_LENGTH"].present? && !env.key?("HTTP_TRANSFER_ENCODING")
      env["CONTENT_LENGTH"].to_i > MAX_BYTES
    else
      read_too_large?(env)
    end
  end

  def read_too_large?(env)
    input = env["rack.input"]
    return false unless input

    body = input.read(MAX_BYTES + 1).to_s
    env["rack.input"] = StringIO.new(body)
    body.bytesize > MAX_BYTES
  end
end
