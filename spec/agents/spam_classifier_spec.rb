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

  describe "#perform" do
    let(:spam_classification_response) do
      {
        "id" => "chatcmpl-123",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
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
        "model" => "gpt-4.1-mini",
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
          expect(body["model"]).to eq("gpt-4.1-mini")
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

  describe "transcript restoration" do
    let(:existing_transcript) do
      [
        { "role" => "developer", "content" => "You are a spam classifier..." },
        { "role" => "user", "content" => "Given the following spam accounts..." },
        {
          "role" => "assistant",
          "content" => "",
          "tool_calls" => [
            {
              "id" => "call_prev",
              "name" => "classify_as_spam",
              "arguments" => {
                "explanation_of_action" => "Previous classification"
              }
            }
          ]
        },
        { "role" => "tool", "content" => "classified as spam", "tool_call_id" => "call_prev" }
      ]
    end

    let(:continued_response) do
      {
        "id" => "chatcmpl-continued",
        "object" => "chat.completion",
        "created" => 1_677_652_288,
        "model" => "gpt-4.1-mini",
        "choices" => [
          {
            "index" => 0,
            "message" => {
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                {
                  "id" => "call_new",
                  "type" => "function",
                  "function" => {
                    "name" => "classify_as_spam",
                    "arguments" => { "explanation_of_action" => "Updated classification" }.to_json
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 50,
          "total_tokens" => 150
        }
      }
    end

    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: continued_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "restores messages including tool calls from an existing transcript" do
      # Pre-create the agent log with an existing transcript
      agent_log =
        AgentLog.create!(
          name: "SpamClassifier",
          state: "processing",
          transcript: existing_transcript,
          owner: target_user
        )

      # Build a new classifier that will find the existing agent log
      classifier = described_class.new(target_user)
      # Override agent_log to use the pre-existing one
      classifier.instance_variable_set(:@agent_log, agent_log)

      classifier.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        messages = body["messages"]

        user_restored =
          messages.find do |m|
            m["role"] == "user" && m["content"]&.include?("Given the following spam accounts")
          end
        assistant_restored = messages.find { |m| m["role"] == "assistant" && m["tool_calls"]&.any? }
        tool_restored =
          messages.find { |m| m["role"] == "tool" && m["tool_call_id"] == "call_prev" }

        user_restored && assistant_restored && tool_restored &&
          assistant_restored["tool_calls"].first["id"] == "call_prev"
      }
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
        "model" => "gpt-4.1-mini",
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
          messages = body["messages"]
          content = messages.find { |m| m["role"] == "user" }&.[]("content")

          # Should contain CSV headers (id column instead of email — see
          # PII-stripping spec below)
          expect(content).to include("id,name,blurb,time zone")

          # Should contain spam examples
          expect(content).to include("Given the following spam accounts:")
          expect(content).to include(spam_user_1.name)
          expect(content).to include(spam_user_2.name)

          # Should contain normal examples
          expect(content).to include("And the following normal accounts:")
          expect(content).to include(normal_user_1.name)
          expect(content).to include(normal_user_2.blurb)

          # Should contain target user (by name; emails are stripped)
          expect(content).to include("Classify the following account as spam or normal:")
          expect(content).to include(target_user.name)

          true
        }
        .at_least_once
    end

    it "does not ship any user email addresses to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

          # No example user's email and no @ from email rows. The CSV
          # header used to be "email,name,..."; verify it has changed.
          expect(content).not_to include(spam_user_1.email)
          expect(content).not_to include(spam_user_2.email)
          expect(content).not_to include(normal_user_1.email)
          expect(content).not_to include(normal_user_2.email)
          expect(content).not_to include(target_user.email)
          expect(content).not_to include("email,name,blurb,time zone")

          true
        }
        .at_least_once
    end

    it "limits spam examples to 50" do
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
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

          spam_section = content.split("And the following normal accounts:").first
          spam_rows = spam_section.split("\n").select { |line| line.start_with?("spam_") }
          expect(spam_rows.length).to be <= 50

          true
        }
        .at_least_once
    end

    it "limits normal examples to 50" do
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
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

          normal_section =
            content
              .split("Classify the following account as spam or normal:")
              .first
              .split("And the following normal accounts:")
              .last
          normal_rows = normal_section.split("\n").select { |line| line.start_with?("normal_") }
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
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
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
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
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
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
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
        expect { subject.perform }.to raise_error(RubyLLM::ServerError)
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

    context "when using ask! (forced tool choice)" do
      let(:tool_call_response) do
        {
          "id" => "chatcmpl-forced",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1-mini",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_forced",
                    "type" => "function",
                    "function" => {
                      "name" => "classify_as_spam",
                      "arguments" => { "explanation_of_action" => "Spam detected" }.to_json
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

      it "sends tool_choice: required to OpenAI" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: tool_call_response.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )

        subject.perform

        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).with { |req|
          body = JSON.parse(req.body)
          body["tool_choice"] == "required"
        }
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
            "model" => "gpt-4.1-mini",
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
      end

      it "completes full classification workflow" do
        subject.perform

        expect(target_user.reload.spam).to be true
        expect(target_user.spam_reason).to eq("auto-spam")
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
            "model" => "gpt-4.1-mini",
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
      end

      it "completes full normal classification workflow" do
        subject.perform

        expect(target_user.reload.spam).to be false
        expect(target_user.spam_reason).to eq("auto-not-spam")
        expect(subject.agent_log.extra_data["explanation_of_action"]).to include("genuine interest")
        expect(subject.agent_log.state).to eq("waiting-for-approval")
      end
    end
  end

  describe "tools" do
    let(:tool_user) { create(:user) }

    describe SpamClassifier::ClassifyAsSpam do
      it "has the correct description" do
        tool = described_class.new(tool_user, AgentLog.create!(name: "test", transcript: []))
        expect(tool.description).to eq("Classify the account as spam")
      end

      it "updates agent log, user, and halts" do
        agent_log = AgentLog.create!(name: "test", transcript: [])
        tool = described_class.new(tool_user, agent_log)
        result = tool.call(explanation_of_action: "Spam patterns detected")

        expect(result).to be_a(RubyLLM::Tool::Halt)
        expect(agent_log.reload.extra_data["spam"]).to be true
        expect(agent_log.extra_data["explanation_of_action"]).to eq("Spam patterns detected")
        expect(tool_user.reload.spam).to be true
        expect(tool_user.spam_reason).to eq("auto-spam")
      end
    end

    describe SpamClassifier::ClassifyAsNormal do
      it "has the correct description" do
        tool = described_class.new(tool_user, AgentLog.create!(name: "test", transcript: []))
        expect(tool.description).to eq("Classify the account as normal")
      end

      it "updates agent log, user, and halts" do
        agent_log = AgentLog.create!(name: "test", transcript: [])
        tool = described_class.new(tool_user, agent_log)
        result = tool.call(explanation_of_action: "Genuine user")

        expect(result).to be_a(RubyLLM::Tool::Halt)
        expect(agent_log.reload.extra_data["spam"]).to be false
        expect(agent_log.extra_data["explanation_of_action"]).to eq("Genuine user")
        expect(tool_user.reload.spam).to be false
        expect(tool_user.spam_reason).to eq("auto-not-spam")
      end
    end
  end

  describe "transcript and usage tracking" do
    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: {
          "id" => "chatcmpl-usage",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4.1-mini",
          "choices" => [
            {
              "index" => 0,
              "message" => {
                "role" => "assistant",
                "content" => "",
                "tool_calls" => [
                  {
                    "id" => "call_usage",
                    "type" => "function",
                    "function" => {
                      "name" => "classify_as_spam",
                      "arguments" => { "explanation_of_action" => "Test" }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 150,
            "completion_tokens" => 75,
            "total_tokens" => 225
          }
        }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "updates agent log transcript" do
      subject.perform

      transcript = subject.agent_log.transcript
      expect(transcript).to be_an(Array)
      expect(transcript.length).to be >= 3
      expect(transcript.any? { |e| e["role"] == "user" }).to be true
      expect(transcript.any? { |e| e["role"] == "assistant" }).to be true
    end

    it "updates agent log usage" do
      subject.perform

      usage = subject.agent_log.usage
      expect(usage["prompt_tokens"]).to eq(150)
      expect(usage["completion_tokens"]).to eq(75)
      expect(usage["total_tokens"]).to eq(225)
      expect(usage["model"]).to eq("gpt-4.1-mini")
    end
  end
end
