require "rails_helper"

describe SafeHttp do
  def stub_resolv(host, addresses)
    allow(Resolv).to receive(:getaddresses).with(host).and_return(addresses)
  end

  describe ".allowed?" do
    it "returns false for blank/invalid URLs" do
      expect(SafeHttp.allowed?(nil)).to be false
      expect(SafeHttp.allowed?("")).to be false
      expect(SafeHttp.allowed?("not a url")).to be false
    end

    it "returns false for non-http(s) schemes" do
      expect(SafeHttp.allowed?("file:///etc/passwd")).to be false
      expect(SafeHttp.allowed?("javascript:alert(1)")).to be false
      expect(SafeHttp.allowed?("data:text/html,<script>")).to be false
      expect(SafeHttp.allowed?("ftp://example.com/x")).to be false
    end

    it "returns false for loopback hosts" do
      expect(SafeHttp.allowed?("http://127.0.0.1/")).to be false
      expect(SafeHttp.allowed?("http://[::1]/")).to be false
    end

    it "returns false for private IPv4 ranges" do
      expect(SafeHttp.allowed?("http://10.0.0.1/")).to be false
      expect(SafeHttp.allowed?("http://192.168.1.1/")).to be false
      expect(SafeHttp.allowed?("http://172.16.0.1/")).to be false
    end

    it "returns false for link-local / metadata addresses" do
      expect(SafeHttp.allowed?("http://169.254.169.254/latest/meta-data/")).to be false
    end

    it "returns false for CGNAT 100.64.0.0/10" do
      expect(SafeHttp.allowed?("http://100.64.0.1/")).to be false
    end

    it "returns false for IPv6 unique-local addresses (fc00::/7)" do
      expect(SafeHttp.allowed?("http://[fd00::1]/")).to be false
    end

    it "returns false for IPv4-mapped IPv6 loopback" do
      expect(SafeHttp.allowed?("http://[::ffff:127.0.0.1]/")).to be false
    end

    it "returns false for 0.0.0.0 sentinel" do
      expect(SafeHttp.allowed?("http://0.0.0.0/")).to be false
    end

    it "returns true when the host resolves to a public IPv4 address" do
      stub_resolv("example.com", ["93.184.216.34"])
      expect(SafeHttp.allowed?("https://example.com/x")).to be true
    end

    it "returns false when the host resolves only to private addresses (DNS-rebinding)" do
      stub_resolv("evil.example", ["10.0.0.1"])
      expect(SafeHttp.allowed?("http://evil.example/")).to be false
    end
  end

  describe ".get" do
    it "raises BlockedError on a non-http scheme" do
      expect { SafeHttp.get("file:///etc/passwd") }.to raise_error(SafeHttp::BlockedError)
    end

    it "raises BlockedError when the host resolves to a private address" do
      stub_resolv("rebind.test", ["10.0.0.5"])
      expect { SafeHttp.get("http://rebind.test/") }.to raise_error(SafeHttp::BlockedError)
    end

    it "raises BlockedError before opening the socket for a literal loopback IP" do
      expect { SafeHttp.get("http://127.0.0.1/") }.to raise_error(SafeHttp::BlockedError)
    end

    it "fetches a public URL and returns the response body" do
      stub_resolv("public.test", ["93.184.216.34"])
      stub_request(:get, "http://public.test/").to_return(status: 200, body: "ok")

      response = SafeHttp.get("http://public.test/")
      expect(response.status).to eq(200)
      expect(response.body).to eq("ok")
    end

    it "re-validates the destination on a redirect and blocks rebinding to a private IP" do
      stub_resolv("public.test", ["93.184.216.34"])
      stub_resolv("private.test", ["10.0.0.7"])
      stub_request(:get, "http://public.test/").to_return(
        status: 302,
        headers: {
          "Location" => "http://private.test/"
        }
      )

      expect { SafeHttp.get("http://public.test/") }.to raise_error(SafeHttp::BlockedError)
    end

    it "follows redirects to public destinations" do
      stub_resolv("first.test", ["93.184.216.34"])
      stub_resolv("second.test", ["8.8.8.8"])
      stub_request(:get, "http://first.test/").to_return(
        status: 302,
        headers: {
          "Location" => "http://second.test/x"
        }
      )
      stub_request(:get, "http://second.test/x").to_return(status: 200, body: "redirected")

      response = SafeHttp.get("http://first.test/")
      expect(response.status).to eq(200)
      expect(response.body).to eq("redirected")
    end

    it "caps response body size and raises ResponseTooLarge" do
      stub_resolv("big.test", ["8.8.8.8"])
      big = "x" * (SafeHttp::MAX_BODY_BYTES + 1)
      stub_request(:get, "http://big.test/").to_return(status: 200, body: big)

      expect { SafeHttp.get("http://big.test/") }.to raise_error(SafeHttp::ResponseTooLarge)
    end
  end

  describe "non-2xx status handling" do
    before { stub_resolv("nx.test", ["8.8.8.8"]) }

    it "raises Faraday::ForbiddenError on a 403" do
      stub_request(:get, "http://nx.test/").to_return(status: 403)
      expect { SafeHttp.get("http://nx.test/") }.to raise_error(Faraday::ForbiddenError)
    end

    it "raises Faraday::ResourceNotFound on a 404" do
      stub_request(:get, "http://nx.test/").to_return(status: 404)
      expect { SafeHttp.get("http://nx.test/") }.to raise_error(Faraday::ResourceNotFound)
    end

    it "raises Faraday::ClientError on a 410" do
      stub_request(:get, "http://nx.test/").to_return(status: 410)
      expect { SafeHttp.get("http://nx.test/") }.to raise_error(Faraday::ClientError)
    end

    it "raises Faraday::ServerError on a 500" do
      stub_request(:get, "http://nx.test/").to_return(status: 500)
      expect { SafeHttp.get("http://nx.test/") }.to raise_error(Faraday::ServerError)
    end
  end

  describe "network-level exception wrapping" do
    before { stub_resolv("broken.test", ["8.8.8.8"]) }

    it "wraps SocketError as Faraday::ConnectionFailed" do
      stub_request(:get, "http://broken.test/").to_raise(SocketError.new("getaddrinfo"))
      expect { SafeHttp.get("http://broken.test/") }.to raise_error(Faraday::ConnectionFailed)
    end

    it "wraps Errno::ECONNREFUSED as Faraday::ConnectionFailed" do
      stub_request(:get, "http://broken.test/").to_raise(Errno::ECONNREFUSED)
      expect { SafeHttp.get("http://broken.test/") }.to raise_error(Faraday::ConnectionFailed)
    end

    it "wraps OpenSSL::SSL::SSLError as Faraday::ConnectionFailed" do
      stub_request(:get, "http://broken.test/").to_raise(OpenSSL::SSL::SSLError.new("bad cert"))
      expect { SafeHttp.get("http://broken.test/") }.to raise_error(Faraday::ConnectionFailed)
    end
  end

  describe ".head" do
    it "raises BlockedError before opening the socket for AWS metadata" do
      expect { SafeHttp.head("http://169.254.169.254/latest/meta-data/") }.to raise_error(
        SafeHttp::BlockedError
      )
    end

    it "fetches a public URL with HEAD" do
      stub_resolv("public.test", ["8.8.8.8"])
      stub_request(:head, "http://public.test/img.png").to_return(
        status: 200,
        headers: {
          "Content-Type" => "image/png"
        }
      )

      response = SafeHttp.head("http://public.test/img.png")
      expect(response.status).to eq(200)
      expect(response.headers["content-type"]).to eq("image/png")
    end
  end
end
