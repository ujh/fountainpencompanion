require "rails_helper"

describe SafeApipieStaticDispatcher do
  let(:app) { ->(_env) { [200, { "content-type" => "text/plain" }, ["app"]] } }
  let(:root) { Apipie::Application::Engine.root.join("app/public").to_s }
  let(:middleware) { described_class.new(app, root) }
  let(:stylesheet) { File.read(File.join(root, "apipie/stylesheets/bundled/bootstrap.min.css")) }

  def call(path, method: "GET")
    env = Rack::MockRequest.env_for("/", method: method)
    env["PATH_INFO"] = path
    middleware.call(env)
  end

  def expect_no_file_lookup
    %i[[] glob].each do |method|
      allow(Dir).to receive(method).and_call_original
      expect(Dir).not_to receive(method).with(a_string_starting_with(root), any_args)
    end
  end

  it "replaces Apipie's dispatcher in the middleware stack" do
    stack = Rails.application.middleware.map(&:klass)

    expect(stack).to include(described_class)
    expect(stack).not_to include(Apipie::StaticDispatcher)
  end

  it "serves a docs asset" do
    status, headers, body = call("/api-docs/stylesheets/bundled/bootstrap.min.css")

    expect(status).to eq(200)
    expect(headers["content-type"]).to eq("text/css")
    expect(body.to_enum(:each).to_a.join).to eq(stylesheet)
  end

  it "answers a HEAD request for a docs asset" do
    status, = call("/api-docs/javascripts/apipie.js", method: "HEAD")

    expect(status).to eq(200)
  end

  it "passes a docs path without a matching asset to the app" do
    status, _headers, body = call("/api-docs/stylesheets/missing.css")

    expect(status).to eq(200)
    expect(body).to eq(["app"])
  end

  [
    "/api-docs/stylesheets/{bundled,x}/bootstrap.min.css",
    "/api-docs/stylesheets/%7Bbundled,x%7D/bootstrap.min.css",
    "/api-docs/stylesheets/bundled/*.css",
    "/api-docs/stylesheets/bundled/%2A.css",
    "/api-docs/stylesheets/bundled/bootstrap.min.cs?",
    "/api-docs/stylesheets/bundled/bootstrap.min.cs%3F",
    "/api-docs/stylesheets/bundled/bootstrap.min.c[s]s",
    "/api-docs/stylesheets/bundled/bootstrap.min.c%5Bs%5Ds",
    "/api-docs/stylesheets/bundled/bootstrap.min.%5Ccss",
    "/inks/{a,b}{a,b}{a,b}"
  ].each do |path|
    it "passes #{path} to the app without looking up files" do
      expect_no_file_lookup

      status, _headers, body = call(path)

      expect(status).to eq(200)
      expect(body).to eq(["app"])
    end
  end

  it "passes a path with an invalid percent-encoding to the app" do
    expect_no_file_lookup

    status, = call("/api-docs/stylesheets/%zz.css")

    expect(status).to eq(200)
  end

  it "passes app paths to the app without looking up files" do
    expect_no_file_lookup

    status, _headers, body = call("/inks")

    expect(status).to eq(200)
    expect(body).to eq(["app"])
  end

  it "passes a POST for a docs asset to the app without looking up files" do
    expect_no_file_lookup

    status, _headers, body = call("/api-docs/stylesheets/bundled/bootstrap.min.css", method: "POST")

    expect(status).to eq(200)
    expect(body).to eq(["app"])
  end

  describe "in the application", type: :request do
    it "renders the API documentation" do
      get "/api-docs"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/api-docs/stylesheets/application.css")
    end

    it "serves the stylesheet the documentation links to" do
      get "/api-docs/stylesheets/application.css"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/css")
    end

    it "hands a docs path with glob characters to the router without looking up files" do
      expect_no_file_lookup

      get "/api-docs/stylesheets/%7Bapplication,x%7D.css"

      expect(response).to have_http_status(:not_acceptable)
    end
  end
end
