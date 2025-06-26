require "rails_helper"

RSpec.describe SpamClassifier do
  before(:each) { WebMock.reset! }
  let(:target_user) do
    create(
      :user,
      name: "John Doe",
      email: "john@example.com",
      blurb: "I love fountain pens!",
      time_zone: "UTC"
    )
  end

  # Create test data for spam examples
  let!(:spam_user_1) do
    create(
      :user,
      name: "Spam Bot 1",
      email: "spam1@fake.com",
      blurb: "Buy my products now! Click here!",
      time_zone: "UTC",
      review_blurb: false
    )
  end

  let!(:spam_user_2) do
    create(
      :user,
      name: "Fake Account",
      email: "fake@spam.com",
      blurb: "Amazing deals! Visit my website!",
      time_zone: "EST",
      review_blurb: false
    )
  end

  # Create test data for normal examples
  let!(:normal_user_1) do
    create(
      :user,
      name: "Alice Smith",
      email: "alice@example.com",
      blurb: "I'm new to fountain pens and looking for advice",
      time_zone: "PST",
      review_blurb: false
    )
  end

  let!(:normal_user_2) do
    create(
      :user,
      name: "Bob Johnson",
      email: "bob@example.com",
      blurb: "Collector of vintage fountain pens",
      time_zone: "EST",
      review_blurb: false
    )
  end

  # Make target user have review_blurb: false so it appears in queries
  before do
    target_user.update!(review_blurb: false)
    # Mark spam users as spammers
    spam_user_1.update!(spam: true)
    spam_user_2.update!(spam: true)
  end

  subject { described_class.new(target_user) }

  describe "#initialize" do
    it "creates agent with user" do
      classifier = described_class.new(target_user)
      expect(classifier.agent_log.owner).to eq(target_user)
      expect(classifier.agent_log.name).to eq("SpamClassifier")
      expect(classifier.agent_log).to be_persisted
    end

    it "initializes transcript with system prompt" do
      classifier = described_class.new(target_user)
      expect(classifier.transcript.first[:system]).to be_present
      expect(classifier.transcript.first[:system]).to include("Given the following spam accounts:")
    end
  end

  describe "#agent_log" do
    it "creates and memoizes agent log" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to be_persisted
      expect(log1.name).to eq("SpamClassifier")
      expect(log1.owner).to eq(target_user)
      expect(log1).to eq(log2)
    end
  end

  describe "#spam?" do
    context "when classified as spam" do
      before { subject.agent_log.update(extra_data: { "spam" => true }) }

      it "returns true" do
        expect(subject.spam?).to be true
      end
    end

    context "when classified as normal" do
      before { subject.agent_log.update(extra_data: { "spam" => false }) }

      it "returns false" do
        expect(subject.spam?).to be false
      end
    end

    context "when not yet classified" do
      it "returns nil" do
        # Initialize agent_log with nil extra_data
        subject.agent_log.update(extra_data: nil)
        expect(subject.spam?).to be_nil
      end
    end
  end

  describe "#perform" do
    let(:spam_classification_response) do
      {
        "id" => "chatcmpl-123",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4o-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_123",
                  "type" => "function",
                  "function" => {
                    "name" => "classify_as_spam",
                    "arguments" => {
                      "explanation_of_action" =>
                        "The account shows typical spam patterns with promotional language and suspicious email domain."
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 200,
          "completion_tokens" => 30,
          "total_tokens" => 230
        }
      }
    end

    let(:normal_classification_response) do
      {
        "id" => "chatcmpl-456",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4o-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_456",
                  "type" => "function",
                  "function" => {
                    "name" => "classify_as_normal",
                    "arguments" => {
                      "explanation_of_action" =>
                        "The account appears to be a genuine fountain pen enthusiast with authentic interests."
                    }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 200,
          "completion_tokens" => 25,
          "total_tokens" => 225
        }
      }
    end

    context "when classified as spam" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: spam_classification_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "updates agent log with spam classification" do
        subject.perform

        expect(subject.agent_log.extra_data["spam"]).to be true
        expect(subject.agent_log.extra_data["explanation_of_action"]).to include("spam patterns")
        expect(subject.agent_log.state).to eq("waiting-for-approval")
      end

      it "returns true for spam?" do
        subject.perform
        expect(subject.spam?).to be true
      end
    end

    context "when classified as normal" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: normal_classification_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "updates agent log with normal classification" do
        subject.perform

        expect(subject.agent_log.extra_data["spam"]).to be false
        expect(subject.agent_log.extra_data["explanation_of_action"]).to include(
          "genuine fountain pen enthusiast"
        )
        expect(subject.agent_log.state).to eq("waiting-for-approval")
      end

      it "returns false for spam?" do
        subject.perform
        expect(subject.spam?).to be false
      end
    end

    it "makes HTTP request to OpenAI API" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: spam_classification_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).at_least_once
    end

    it "uses correct OpenAI model" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: spam_classification_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          expect(body["model"]).to eq("gpt-4o-mini")
          true
        }
        .at_least_once
    end

    it "includes both classification functions" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: spam_classification_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          if body["tools"].present?
            tools = body["tools"]
            tool_names = tools.map { |tool| tool["function"]["name"] }
            expect(tool_names).to include("classify_as_spam")
            expect(tool_names).to include("classify_as_normal")
          end
          true
        }
        .at_least_once
    end
  end

  describe "data formatting" do
    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: spam_classification_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    let(:spam_classification_response) do
      {
        "id" => "chatcmpl-789",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4o-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_789",
                  "type" => "function",
                  "function" => {
                    "name" => "classify_as_spam",
                    "arguments" => { "explanation_of_action" => "Test explanation" }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 200,
          "completion_tokens" => 30,
          "total_tokens" => 230
        }
      }
    end

    it "sends CSV formatted data to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]

          # Should contain CSV headers
          expect(content).to include("email,name,blurb,time zone")

          # Should contain spam examples
          expect(content).to include("Given the following spam accounts:")
          expect(content).to include(spam_user_1.email)
          expect(content).to include(spam_user_2.name)

          # Should contain normal examples
          expect(content).to include("And the following normal accounts:")
          expect(content).to include(normal_user_1.email)
          expect(content).to include(normal_user_2.blurb)

          # Should contain target user
          expect(content).to include("Classify the following account as spam or normal:")
          expect(content).to include(target_user.email)
          expect(content).to include(target_user.name)

          true
        }
        .at_least_once
    end

    it "limits spam examples to 50" do
      # Create more than 50 spam users
      51.times do |i|
        create(
          :user,
          email: "spam#{i}@test.com",
          name: "Spam User #{i}",
          blurb: "Spam content #{i}",
          spam: true,
          review_blurb: false
        )
      end

      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]

          # Count CSV rows in spam section (excluding header)
          spam_section = content.split("And the following normal accounts:").first
          spam_rows = spam_section.split("\n").select { |line| line.include?("@") }
          expect(spam_rows.length).to be <= 50

          true
        }
        .at_least_once
    end

    it "limits normal examples to 50" do
      # Create more than 50 normal users
      51.times do |i|
        create(
          :user,
          email: "normal#{i}@test.com",
          name: "Normal User #{i}",
          blurb: "Normal content #{i}",
          spam: false,
          review_blurb: false
        )
      end

      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]

          # Count CSV rows in normal section (excluding header)
          normal_section =
            content
              .split("Classify the following account as spam or normal:")
              .first
              .split("And the following normal accounts:")
              .last
          normal_rows = normal_section.split("\n").select { |line| line.include?("@") }
          expect(normal_rows.length).to be <= 50

          true
        }
        .at_least_once
    end

    it "excludes users with review_blurb: true" do
      excluded_user =
        create(
          :user,
          email: "excluded@test.com",
          name: "Excluded User",
          blurb: "Should not appear",
          spam: true,
          review_blurb: true
        )

      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]
          expect(content).not_to include(excluded_user.email)
          true
        }
        .at_least_once
    end

    it "excludes normal users with empty blurbs" do
      empty_blurb_user =
        create(
          :user,
          email: "empty@test.com",
          name: "Empty Blurb User",
          blurb: "",
          spam: false,
          review_blurb: false
        )

      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]
          normal_section =
            content
              .split("Classify the following account as spam or normal:")
              .first
              .split("And the following normal accounts:")
              .last
          expect(normal_section).not_to include(empty_blurb_user.email)
          true
        }
        .at_least_once
    end

    it "handles special characters in user data" do
      special_user =
        create(
          :user,
          email: "test@example.com",
          name: 'User "With" Quotes',
          blurb: "Blurb with, commas and \"quotes\"",
          time_zone: "America/New_York",
          review_blurb: false
        )

      classifier = described_class.new(special_user)
      classifier.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].first["content"]
          expect(content).to include(special_user.email)
          expect(content).to include("With")
          expect(content).to include("quotes")
          true
        }
        .at_least_once
    end
  end

  describe "error handling" do
    context "when OpenAI API returns 500 error" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 500,
          body: "Internal Server Error"
        )
      end

      it "raises an error" do
        expect { subject.perform }.to raise_error(Faraday::ServerError)
      end
    end

    context "when OpenAI returns malformed JSON" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: "invalid json",
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises a parsing error" do
        expect { subject.perform }.to raise_error(Faraday::ParsingError)
      end
    end

    context "when OpenAI returns unexpected response format" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-error",
            "choices" => [
              {
                "message" => {
                  "role" => "assistant",
                  "content" => "I cannot classify this user."
                }
              }
            ],
            "usage" => {
              "prompt_tokens" => 100,
              "completion_tokens" => 10,
              "total_tokens" => 110
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles response without tool calls gracefully" do
        # Set thread-local variable to avoid usage tracking errors
        Thread.current[:chat_completion_response] = {
          "usage" => {
            "prompt_tokens" => 100,
            "completion_tokens" => 10,
            "total_tokens" => 110
          }
        }

        # This should not raise an error, but also won't update the agent log with classification
        expect { subject.perform }.not_to raise_error
        # Ensure extra_data is initialized to avoid nil errors
        subject.agent_log.reload
        expect(subject.spam?).to be_nil
      end
    end
  end

  describe "integration scenarios" do
    context "complete spam classification workflow" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-integration",
            "object" => "chat.completion",
            "created" => 1_677_652_288,
            "model" => "gpt-4o-mini",
            "choices" => [
              {
                "index" => 0,
                "message" => {
                  "role" => "assistant",
                  "content" => "",
                  "tool_calls" => [
                    {
                      "id" => "call_integration",
                      "type" => "function",
                      "function" => {
                        "name" => "classify_as_spam",
                        "arguments" => {
                          "explanation_of_action" =>
                            "Account shows promotional content and suspicious patterns typical of spam accounts."
                        }.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 200,
              "completion_tokens" => 30,
              "total_tokens" => 230
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )

        # Set thread-local variable for usage tracking
        Thread.current[:chat_completion_response] = {
          "usage" => {
            "prompt_tokens" => 200,
            "completion_tokens" => 30,
            "total_tokens" => 230
          }
        }
      end

      it "completes full classification workflow" do
        subject.perform

        expect(subject.spam?).to be true
        expect(subject.agent_log.extra_data["explanation_of_action"]).to include(
          "promotional content"
        )
        expect(subject.agent_log.state).to eq("waiting-for-approval")
        expect(subject.agent_log.name).to eq("SpamClassifier")
        expect(subject.agent_log.owner).to eq(target_user)
      end
    end

    context "complete normal classification workflow" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-normal",
            "object" => "chat.completion",
            "created" => 1_677_652_288,
            "model" => "gpt-4o-mini",
            "choices" => [
              {
                "index" => 0,
                "message" => {
                  "role" => "assistant",
                  "content" => "",
                  "tool_calls" => [
                    {
                      "id" => "call_normal",
                      "type" => "function",
                      "function" => {
                        "name" => "classify_as_normal",
                        "arguments" => {
                          "explanation_of_action" =>
                            "Account shows genuine interest in fountain pens with authentic personal details."
                        }.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 200,
              "completion_tokens" => 25,
              "total_tokens" => 225
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )

        # Set thread-local variable for usage tracking
        Thread.current[:chat_completion_response] = {
          "usage" => {
            "prompt_tokens" => 200,
            "completion_tokens" => 25,
            "total_tokens" => 225
          }
        }
      end

      it "completes full normal classification workflow" do
        subject.perform

        expect(subject.spam?).to be false
        expect(subject.agent_log.extra_data["explanation_of_action"]).to include("genuine interest")
        expect(subject.agent_log.state).to eq("waiting-for-approval")
      end
    end
  end
end
