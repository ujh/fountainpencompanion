require "rails_helper"

describe "Rack::Attack throttles", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before do
    # Per-example cache so throttle counters don't leak between tests.
    @original_cache = Rack::Attack.cache.store
    @original_enabled = Rack::Attack.enabled
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    # Freeze time so a burst of requests can't straddle a Rack::Attack
    # period boundary and reset the counter mid-test.
    freeze_time
  end

  after do
    travel_back
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

  describe "hourly login throttle on POST /users/sign_in" do
    it "allows 20 attempts per hour for the same email and throttles the 21st" do
      travel_to Time.current.beginning_of_hour
      results =
        statuses(21) do |i|
          travel 61.seconds if i.positive? && (i % 5).zero?
          post "/users/sign_in",
               params: {
                 user: {
                   email: "slow-victim@example.com",
                   password: "wrong"
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.#{150 + i}"
               }
        end

      expect(results.first(20)).to all(be < 429)
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

  describe "magic link throttles on POST /users/sign_in without a password" do
    # Windows are epoch-aligned; start at minute one so the travels below stay inside one window.
    before { travel_to Time.zone.at((Time.now.to_i / 3600) * 3600 + 60) }

    it "allows the first 3 sends and throttles the 4th for the same email across IPs" do
      results =
        statuses(4) do |i|
          post "/users/sign_in",
               params: {
                 user: {
                   email: "magic-victim@example.com",
                   password: ""
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.#{i + 60}"
               }
        end

      expect(results.first(3)).to all(be < 429)
      expect(results.last).to eq(429)
    end

    it "allows the first 10 sends and throttles the 11th from the same IP" do
      results =
        statuses(11) do |i|
          travel 30.seconds
          post "/users/sign_in",
               params: {
                 user: {
                   email: "magic-#{i}@example.com"
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.70"
               }
        end

      expect(results.first(10)).to all(be < 429)
      expect(results.last).to eq(429)
    end

    it "does not count password logins against the magic link limits" do
      results =
        statuses(4) do |i|
          travel 30.seconds
          post "/users/sign_in",
               params: {
                 user: {
                   email: "pw-user@example.com",
                   password: "wrong"
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.#{i + 80}"
               }
        end

      expect(results).to all(be < 429)
    end
  end

  describe "email change throttles on PUT/PATCH /users" do
    let(:user) { create(:user, password: "password123") }

    before { sign_in(user) }

    it "allows the first 3 attempts and throttles the 4th from the same IP" do
      results =
        statuses(4) do |i|
          put "/users",
              params: {
                user: {
                  email: "change-#{i}@example.com",
                  current_password: "password123"
                }
              },
              env: {
                "REMOTE_ADDR" => "203.0.113.90"
              }
        end

      expect(results.first(3)).to all(be < 429)
      expect(results.last).to eq(429)
    end

    it "allows the first 3 attempts and throttles the 4th for the same email across IPs" do
      results =
        statuses(4) do |i|
          patch "/users",
                params: {
                  user: {
                    email: "mail-victim@example.com",
                    current_password: "password123"
                  }
                },
                env: {
                  "REMOTE_ADDR" => "203.0.113.#{i + 100}"
                }
        end

      expect(results.first(3)).to all(be < 429)
      expect(results.last).to eq(429)
    end
  end

  describe "confirmation resend throttles on POST /users/confirmation" do
    it "allows the first 3 attempts and throttles the 4th for the same email across IPs" do
      results =
        statuses(4) do |i|
          post "/users/confirmation",
               params: {
                 user: {
                   email: "unconfirmed@example.com"
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.#{i + 120}"
               }
        end

      expect(results.first(3)).to all(be < 429)
      expect(results.last).to eq(429)
    end

    it "allows the first 5 attempts and throttles the 6th from the same IP" do
      results =
        statuses(6) do |i|
          post "/users/confirmation",
               params: {
                 user: {
                   email: "unconfirmed-#{i}@example.com"
                 }
               },
               env: {
                 "REMOTE_ADDR" => "203.0.113.130"
               }
        end

      expect(results.first(5)).to all(be < 429)
      expect(results.last).to eq(429)
    end
  end

  describe "fpc_devise_user_params" do
    it "ignores a user parameter that is not a hash" do
      env =
        Rack::MockRequest.env_for("/users/confirmation", method: "POST", params: { user: "scalar" })
      request = Rack::Request.new(env)
      expect(fpc_devise_email(request)).to be_nil
      expect(fpc_magic_link_request?(request)).to eq(false)
    end
  end

  describe "search throttles" do
    it "throttles /inks?q= by IP" do
      results =
        statuses(2) do
          get "/inks", params: { q: "blue" }, env: { "REMOTE_ADDR" => "203.0.113.200" }
        end
      expect(results).to eq([200, 429])
    end

    it "throttles /inks when the parameter name is percent-encoded" do
      results = statuses(2) { get "/inks?%71=blue", env: { "REMOTE_ADDR" => "203.0.113.201" } }
      expect(results.last).to eq(429)
    end

    it "throttles /inks when q is sent as an array" do
      results = statuses(2) { get "/inks?q[]=blue", env: { "REMOTE_ADDR" => "203.0.113.202" } }
      expect(results.last).to eq(429)
    end

    it "does not throttle /inks tag browsing" do
      results =
        statuses(2) do
          get "/inks", params: { tag: "blue" }, env: { "REMOTE_ADDR" => "203.0.113.203" }
        end
      expect(results).to all(be < 429)
    end

    it "throttles /pen_models?q= by IP" do
      allow(Pens::Model).to receive(:embedding_search).and_return([])
      results =
        statuses(2) do
          get "/pen_models", params: { q: "eco" }, env: { "REMOTE_ADDR" => "203.0.113.204" }
        end
      expect(results).to eq([200, 429])
    end

    it "does not throttle /pen_models without a query" do
      results = statuses(2) { get "/pen_models", env: { "REMOTE_ADDR" => "203.0.113.205" } }
      expect(results).to all(be < 429)
    end
  end

  describe "ink review submission throttle" do
    let(:path) { "/brands/1/inks/2/ink_review_submissions" }

    it "allows the first 20 submissions and throttles the 21st from the same IP" do
      results = statuses(21) { post path, env: { "REMOTE_ADDR" => "203.0.113.210" } }

      expect(results.first(20)).to all(be < 429)
      expect(results.last).to eq(429)
    end

    it "throttles JSON submissions" do
      results = statuses(21) { post "#{path}.json", env: { "REMOTE_ADDR" => "203.0.113.211" } }

      expect(results.last).to eq(429)
    end

    it "keeps separate buckets per IP" do
      statuses(20) { post path, env: { "REMOTE_ADDR" => "203.0.113.212" } }
      post path, env: { "REMOTE_ADDR" => "203.0.113.213" }

      expect(response.status).to be < 429
    end
  end

  describe "pen and ink suggestion enqueue throttle" do
    let(:path) { "/dashboard/widgets/pen_and_ink_suggestion.json" }
    let(:env) { { "REMOTE_ADDR" => "203.0.113.230" } }

    def use_up_enqueue_limit
      statuses(10) { get path, env: env }
    end

    it "allows the first 10 enqueues and throttles the 11th from the same IP" do
      results = statuses(11) { get path, env: env }

      expect(results.first(10)).to all(be < 429)
      expect(results.last).to eq(429)
    end

    it "never throttles polls that carry a suggestion_id" do
      use_up_enqueue_limit
      results =
        statuses(30) do |i|
          get path, params: { suggestion_id: "request-pen-and-ink-suggestion-#{i}" }, env: env
        end

      expect(results).to all(be < 429)
    end

    it "throttles enqueues on the path without .json" do
      use_up_enqueue_limit
      get "/dashboard/widgets/pen_and_ink_suggestion", env: env

      expect(response.status).to eq(429)
    end

    it "throttles enqueues with an empty suggestion_id" do
      use_up_enqueue_limit
      get path, params: { suggestion_id: "" }, env: env

      expect(response.status).to eq(429)
    end

    it "throttles enqueues with a whitespace suggestion_id" do
      use_up_enqueue_limit
      get "#{path}?suggestion_id=%20", env: env

      expect(response.status).to eq(429)
    end

    %w[
      /dashboard/widgets/pen%5Fand%5Fink%5Fsuggestion.json
      /dashboard/widgets/pen_and_ink_suggestion.html
    ].each do |variant|
      it "throttles enqueues on #{variant}" do
        use_up_enqueue_limit
        get variant, env: env

        expect(response.status).to eq(429)
      end
    end

    it "keeps separate buckets per IP" do
      use_up_enqueue_limit
      get path, env: { "REMOTE_ADDR" => "203.0.113.231" }

      expect(response.status).to be < 429
    end

    it "does not throttle other dashboard widgets" do
      use_up_enqueue_limit
      get "/dashboard/widgets/inks_summary.json", env: env

      expect(response.status).to be < 429
    end
  end

  describe "fpc_pen_and_ink_suggestion_enqueue?" do
    def enqueue?(path, query = "")
      env = Rack::MockRequest.env_for("/")
      env["PATH_INFO"] = path
      env["QUERY_STRING"] = query
      fpc_pen_and_ink_suggestion_enqueue?(Rack::Request.new(env))
    end

    %w[
      /dashboard/widgets/pen_and_ink_suggestion
      /dashboard/widgets/pen_and_ink_suggestion.json
      /dashboard/widgets/pen_and_ink_suggestion/
      /dashboard/widgets/pen_and_ink_suggestion.json/
      //dashboard//widgets/pen_and_ink_suggestion
      /dashboard/widgets/pen%5Fand%5Fink%5Fsuggestion.json
      /dashboard/widgets/pen_and_ink_suggestion.html
    ].each do |path|
      it "matches #{path}, which routes to the suggestion widget" do
        expect(Rails.application.routes.recognize_path(path)).to include(
          controller: "widgets",
          action: "show",
          id: "pen_and_ink_suggestion"
        )
        expect(enqueue?(path)).to eq(true)
      end
    end

    it "matches a blank suggestion_id" do
      expect(enqueue?("/dashboard/widgets/pen_and_ink_suggestion.json", "suggestion_id=")).to eq(
        true
      )
      expect(enqueue?("/dashboard/widgets/pen_and_ink_suggestion.json", "suggestion_id=%20")).to eq(
        true
      )
    end

    it "does not match a poll" do
      expect(enqueue?("/dashboard/widgets/pen_and_ink_suggestion.json", "suggestion_id=abc")).to eq(
        false
      )
    end

    it "does not match other widgets" do
      expect(enqueue?("/dashboard/widgets/inks_summary.json")).to eq(false)
      expect(enqueue?("/dashboard/widgets/pen_and_ink_suggestions.json")).to eq(false)
      expect(enqueue?("/dashboard/widgets/pen_and_ink_suggestion/extra")).to eq(false)
    end
  end

  describe "CSP report throttle" do
    it "allows the first 30 reports and throttles the 31st from the same IP" do
      results = statuses(31) { post "/csp-reports", env: { "REMOTE_ADDR" => "203.0.113.220" } }

      expect(results.first(30)).to all(be < 429)
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

    it "throttles /api/* by token across IPs" do
      results =
        statuses(16) do |i|
          get "/api/v1/collected_inks",
              env: {
                "REMOTE_ADDR" => "203.0.113.#{100 + i}",
                "HTTP_AUTHORIZATION" => %(Token token="same-id.same-secret")
              }
        end

      expect(results.first(15)).to all(be < 429)
      expect(results.last).to eq(429)
    end

    it "does not let requests with a guessed token id use up the real token's bucket" do
      statuses(15) do |i|
        get "/api/v1/collected_inks",
            env: {
              "REMOTE_ADDR" => "203.0.113.#{100 + i}",
              "HTTP_AUTHORIZATION" => %(Token token="victim-id.garbage-#{i}")
            }
      end

      get "/api/v1/collected_inks",
          env: {
            "REMOTE_ADDR" => "203.0.113.150",
            "HTTP_AUTHORIZATION" => %(Token token="victim-id.real-secret")
          }

      expect(response.status).to be < 429
    end
  end
end
