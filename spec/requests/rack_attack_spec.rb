require "rails_helper"

describe "Rack::Attack throttles", type: :request do
  before do
    # Per-example cache so throttle counters don't leak between tests.
    @original_cache = Rack::Attack.cache.store
    @original_enabled = Rack::Attack.enabled
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
  end

  after do
    Rack::Attack.cache.store = @original_cache
    Rack::Attack.enabled = @original_enabled
  end

  def statuses(count, &block)
    Array.new(count) do |i|
      block.call(i)
      response.status
    end
  end

  describe "login throttles on POST /users/sign_in" do
    it "allows the first 5 attempts and throttles the 6th from the same IP" do
      results =
        statuses(6) do |i|
          post "/users/sign_in",
               params: {
                 user: {
                   email: "ip-victim-#{i}@example.com",
                   password: "wrong"
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.1"
               }
        end

      expect(results.first(5)).to all(be < 429)
      expect(results.last).to eq(429)
    end

    it "allows the first 5 attempts and throttles the 6th for the same email across IPs" do
      results =
        statuses(6) do |i|
          post "/users/sign_in",
               params: {
                 user: {
                   email: "victim@example.com",
                   password: "wrong"
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.#{i + 10}"
               }
        end

      expect(results.first(5)).to all(be < 429)
      expect(results.last).to eq(429)
    end
  end

  describe "password reset throttles on POST /users/password" do
    it "allows the first 3 attempts and throttles the 4th for the same email" do
      results =
        statuses(4) do |i|
          post "/users/password",
               params: {
                 user: {
                   email: "reset-victim@example.com"
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.#{i + 20}"
               }
        end

      expect(results.first(3)).to all(be < 429)
      expect(results.last).to eq(429)
    end
  end

  describe "signup throttle on POST /users" do
    before do
      stub_request(:post, "https://api.hcaptcha.com/siteverify").to_return(
        status: 200,
        body: { success: true }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "allows the first 5 attempts and throttles the 6th from the same IP" do
      results =
        statuses(6) do |i|
          post "/users",
               params: {
                 user: {
                   email: "signup-#{i}@example.com",
                   password: "password123"
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.50"
               }
        end

      expect(results.first(5)).to all(be < 429)
      expect(results.last).to eq(429)
    end
  end

  describe "API token throttles" do
    it "throttles /api/* requests by IP when the Authorization header changes per request" do
      # Rotate a fake bearer token on every request. The old per-header
      # throttle would have given each value its own bucket; the new
      # per-IP /api/* throttle catches this pattern.
      results =
        statuses(61) do |i|
          get "/api/v1/collected_inks",
              env: {
                "REMOTE_ADDR" => "203.0.113.77",
                "HTTP_AUTHORIZATION" => %(Token token="garbage-#{i}.secret")
              }
        end

      expect(results.first(60)).to all(be < 429)
      expect(results.last).to eq(429)
    end

    it "throttles /api/* by token id across rotating secrets" do
      # Same token id with rotating secret halves should hit the
      # per-token-id throttle even from different IPs.
      results =
        statuses(16) do |i|
          get "/api/v1/collected_inks",
              env: {
                "REMOTE_ADDR" => "203.0.113.#{100 + i}",
                "HTTP_AUTHORIZATION" => %(Token token="same-id.secret-#{i}")
              }
        end

      expect(results.first(15)).to all(be < 429)
      expect(results.last).to eq(429)
    end
  end
end
