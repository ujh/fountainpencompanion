require "rails_helper"

describe FlyClientIp do
  let(:app) { ->(env) { [200, {}, [env]] } }
  let(:middleware) { described_class.new(app) }

  def call(headers)
    middleware.call(Rack::MockRequest.env_for("/", headers)).last.first
  end

  it "runs before the middleware that reads the client IP" do
    stack = Rails.application.middleware.map(&:klass)

    expect(stack.index(described_class)).to be < stack.index(ActionDispatch::RemoteIp)
    expect(stack.index(described_class)).to be < stack.index(Rack::Attack)
  end

  context "when Fly sets Fly-Client-IP" do
    let(:env) do
      call(
        "REMOTE_ADDR" => "172.16.4.186",
        "HTTP_FLY_CLIENT_IP" => "198.51.100.7",
        "HTTP_X_FORWARDED_FOR" => "10.0.0.1, 198.51.100.7, 66.241.124.196",
        "HTTP_FORWARDED" => "for=10.0.0.1",
        "HTTP_CLIENT_IP" => "10.0.0.2"
      )
    end

    it "replaces X-Forwarded-For with the Fly client IP" do
      expect(env["HTTP_X_FORWARDED_FOR"]).to eq("198.51.100.7")
    end

    it "drops the client-supplied Forwarded and Client-IP headers" do
      expect(env).not_to include("HTTP_FORWARDED", "HTTP_CLIENT_IP")
    end

    it "makes Rails and Rack resolve the Fly client IP" do
      expect(ActionDispatch::Request.new(env).remote_ip).to eq("198.51.100.7")
      expect(Rack::Request.new(env).ip).to eq("198.51.100.7")
    end
  end

  context "without Fly-Client-IP" do
    it "leaves the request headers alone" do
      env =
        call(
          "REMOTE_ADDR" => "172.16.4.186",
          "HTTP_X_FORWARDED_FOR" => "203.0.113.9",
          "HTTP_FORWARDED" => "for=203.0.113.9",
          "HTTP_CLIENT_IP" => "203.0.113.9"
        )

      expect(env).to include(
        "HTTP_X_FORWARDED_FOR" => "203.0.113.9",
        "HTTP_FORWARDED" => "for=203.0.113.9",
        "HTTP_CLIENT_IP" => "203.0.113.9"
      )
    end
  end

  context "with an empty Fly-Client-IP" do
    it "leaves X-Forwarded-For alone" do
      env = call("HTTP_FLY_CLIENT_IP" => "", "HTTP_X_FORWARDED_FOR" => "203.0.113.9")

      expect(env["HTTP_X_FORWARDED_FOR"]).to eq("203.0.113.9")
    end
  end
end
