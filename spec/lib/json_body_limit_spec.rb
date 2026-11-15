require "rails_helper"

describe JsonBodyLimit do
  let(:app) do
    lambda do |env|
      request = ActionDispatch::Request.new(env)
      [200, {}, [request.raw_post]]
    end
  end
  let(:middleware) { described_class.new(app) }
  let(:limit) { 1.megabyte }

  def json_body(bytes)
    prefix = '{"comment":"'
    suffix = '"}'
    prefix + ("x" * (bytes - prefix.bytesize - suffix.bytesize)) + suffix
  end

  def call(body, content_type, headers = {}, content_length: true)
    env =
      Rack::MockRequest.env_for(
        "/api/v1/collected_inks",
        { :method => "POST", :input => body, "CONTENT_TYPE" => content_type }.merge(headers)
      )
    env.delete("CONTENT_LENGTH") unless content_length
    middleware.call(env)
  end

  it "runs before Rack::Attack, which parses JSON bodies" do
    stack = Rails.application.middleware.map(&:klass)

    expect(stack.index(described_class)).to be < stack.index(Rack::Attack)
  end

  {
    "application/json" => "application/json",
    "application/vnd.api+json" => "application/vnd.api+json",
    "Application/JSON; charset=utf-8" => "application/json"
  }.each do |type, response_type|
    context "with #{type}" do
      it "rejects a body larger than 1 MB" do
        status, headers, body = call(json_body(limit + 1), type)

        expect(status).to eq(413)
        expect(headers["content-type"]).to eq(response_type)
        expect(JSON.parse(body.join)).to eq(
          "errors" => [{ "status" => "413", "title" => "Payload Too Large" }]
        )
      end

      it "rejects a body larger than 1 MB without a Content-Length" do
        status, = call(json_body(limit + 1), type, content_length: false)

        expect(status).to eq(413)
      end

      it "rejects a chunked body larger than 1 MB" do
        status, =
          call(
            json_body(limit + 1),
            type,
            { "HTTP_TRANSFER_ENCODING" => "chunked" },
            content_length: false
          )

        expect(status).to eq(413)
      end

      it "passes a body of 1 MB through" do
        body = json_body(limit)
        status, _headers, response = call(body, type)

        expect(status).to eq(200)
        expect(response.join).to eq(body)
      end

      it "passes a chunked body of 1 MB through unchanged" do
        body = json_body(limit)
        status, _headers, response =
          call(body, type, { "HTTP_TRANSFER_ENCODING" => "chunked" }, content_length: false)

        expect(status).to eq(200)
        expect(response.join).to eq(body)
      end
    end
  end

  it "reads the body when a Transfer-Encoding comes with a small Content-Length" do
    env =
      Rack::MockRequest.env_for(
        "/",
        :method => "POST",
        :input => json_body(limit + 1),
        "CONTENT_TYPE" => "application/json",
        "HTTP_TRANSFER_ENCODING" => "chunked"
      )
    env["CONTENT_LENGTH"] = "10"

    status, = middleware.call(env)

    expect(status).to eq(413)
  end

  it "lets the app parse a small JSON body without a Content-Length" do
    app = ->(env) { [200, {}, [ActionDispatch::Request.new(env).request_parameters.to_json]] }
    env =
      Rack::MockRequest.env_for(
        "/",
        :method => "POST",
        :input => '{"comment":"Great ink"}',
        "CONTENT_TYPE" => "application/json",
        "HTTP_TRANSFER_ENCODING" => "chunked"
      )
    env.delete("CONTENT_LENGTH")

    _status, _headers, body = described_class.new(app).call(env)

    expect(JSON.parse(body.join)).to eq("comment" => "Great ink")
  end

  it "passes a large multipart body through" do
    status, = call("x" * (limit + 1), "multipart/form-data; boundary=fpc")

    expect(status).to eq(200)
  end

  it "passes a large form body through" do
    status, = call("comment=#{"x" * limit}", "application/x-www-form-urlencoded")

    expect(status).to eq(200)
  end

  it "passes a large body with an invalid content type through" do
    status, = call("x" * (limit + 1), "invalid content type/")

    expect(status).to eq(200)
  end

  it "passes a GET without a body through" do
    status, = middleware.call(Rack::MockRequest.env_for("/api/v1/collected_inks"))

    expect(status).to eq(200)
  end

  describe "in the application", type: :request do
    it "rejects an oversized JSON:API body before it reaches the controller" do
      user = create(:user)
      sign_in(user)

      post "/api/v1/collected_inks",
           params: json_body(limit + 1),
           headers: {
             "CONTENT_TYPE" => "application/vnd.api+json",
             "ACCEPT" => "application/json"
           }

      expect(response).to have_http_status(:content_too_large)
      expect(user.collected_inks).to be_empty
    end
  end
end
