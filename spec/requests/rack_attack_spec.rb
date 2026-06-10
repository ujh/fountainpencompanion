require "rails_helper"

describe "Rack::Attack throttles", type: :request do
  before do
    # Use a real (memory) cache so throttle counters persist across requests
    # within a test. The test environment normally uses :null_store / clears
    # Rails.cache between tests via the global before(:each), so isolation
    # between examples is already handled.
    @original_cache = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
  end

  after { Rack::Attack.cache.store = @original_cache }

  describe "login throttles on POST /users/sign_in" do
    it "throttles by IP after 5 attempts in 20 seconds" do
      6.times do |i|
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

      expect(response).to have_http_status(:too_many_requests)
    end

    it "throttles by email regardless of IP" do
      6.times do |i|
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

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "password reset throttles on POST /users/password" do
    it "throttles by email after 3 attempts in 1 hour" do
      4.times do |i|
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

      expect(response).to have_http_status(:too_many_requests)
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

    it "throttles by IP after 5 attempts in 1 hour" do
      6.times do |i|
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

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
