require "rails_helper"

RSpec.describe GoogleSearchSummarizer do
  before(:each) { WebMock.reset! }

  let(:parent_agent_log) { AgentLog.create!(name: "ParentAgent", transcript: []) }
  let(:search_term) { "Pilot Iroshizuku Kon-peki ink" }
  let(:serper_api_response) do
    {
      "organic" => [
        {
          "title" => "Pilot Iroshizuku Kon-peki - Deep Azure Blue Fountain Pen Ink",
          "link" => "https://example.com/pilot-iroshizuku-kon-peki",
          "snippet" =>
            "Pilot Iroshizuku Kon-peki is a beautiful deep azure blue fountain pen ink. Perfect for daily writing and special occasions."
        },
        {
          "title" => "Review: Pilot Iroshizuku Kon-peki Ink",
          "link" => "https://example.com/review-kon-peki",
          "snippet" =>
            "A comprehensive review of Pilot's popular Kon-peki ink. Great flow and beautiful color variation."
        }
      ],
      "searchInformation" => {
        "totalResults" => "2450"
      }
    }
  end
  let(:normalized_search_results) do
    {
      "items" =>
        serper_api_response["organic"].map do |r|
          { "title" => r["title"], "link" => r["link"], "snippet" => r["snippet"] }
        end,
      "searchInformation" => {
        "totalResults" => "2450"
      }
    }
  end

  subject { described_class.new(search_term, parent_agent_log: parent_agent_log) }

  before do
    stub_request(:post, %r{google\.serper\.dev/search}).to_return(
      status: 200,
      body: serper_api_response.to_json,
      headers: {
        "Content-Type" => "application/json"
      }
    )
  end

  describe "#initialize" do
    it "creates agent with search term and parent agent log" do
      summarizer = described_class.new(search_term, parent_agent_log: parent_agent_log)
      expect(summarizer.send(:search_term)).to eq(search_term)
      expect(summarizer.send(:parent_agent_log)).to eq(parent_agent_log)
    end
  end

  describe "#agent_log" do
    it "creates and memoizes agent log owned by parent agent log" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to be_persisted
      expect(log1.name).to eq("GoogleSearchSummarizer")
      expect(log1.owner).to eq(parent_agent_log)
      expect(log1).to eq(log2)
    end

    it "finds existing processing agent log if it exists" do
      existing_log =
        parent_agent_log.agent_logs.create!(
          name: "GoogleSearchSummarizer",
          state: "processing",
          transcript: []
        )

      expect(subject.agent_log).to eq(existing_log)
    end
  end

  describe "transcript restoration" do
    let(:existing_transcript) do
      [
        { "role" => "developer", "content" => "You are tasked with summarizing..." },
        { "role" => "user", "content" => "The search was done for: test ink" },
        {
          "role" => "assistant",
          "content" => "",
          "tool_calls" => [
            {
              "id" => "call_prev",
              "name" => "summarize_search_results",
              "arguments" => {
                "summary" => "Previous summary"
              }
            }
          ]
        },
        { "role" => "tool", "content" => "Previous summary", "tool_call_id" => "call_prev" }
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
                    "name" => "summarize_search_results",
                    "arguments" => { "summary" => "Updated summary" }.to_json
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
      parent_agent_log.agent_logs.create!(
        name: "GoogleSearchSummarizer",
        state: "processing",
        transcript: existing_transcript
      )

      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).with { |req|
        body = JSON.parse(req.body)
        messages = body["messages"]

        # Should have: developer, user (restored), assistant with tool_calls (restored),
        #              tool result (restored), user (new ask)
        user_restored =
          messages.find do |m|
            m["role"] == "user" && m["content"] == "The search was done for: test ink"
          end
        assistant_restored = messages.find { |m| m["role"] == "assistant" && m["tool_calls"]&.any? }
        tool_restored =
          messages.find { |m| m["role"] == "tool" && m["tool_call_id"] == "call_prev" }

        user_restored && assistant_restored && tool_restored &&
          assistant_restored["tool_calls"].first["id"] == "call_prev"
      }
    end
  end

  describe "#perform" do
    let(:successful_response) do
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
                    "name" => "summarize_search_results",
                    "arguments" => {
                      "summary" =>
                        "Found 2,450 results for 'Pilot Iroshizuku Kon-peki ink'. This is a high number of results indicating a well-known product. Pilot Iroshizuku Kon-peki is a popular deep azure blue fountain pen ink known for its beautiful color and good flow characteristics. Alternative names include 'Deep Azure Blue' and 'Kon-peki Blue'."
                    }.to_json
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
      }
    end

    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "performs a Google search" do
      subject.perform

      expect(WebMock).to have_requested(:post, %r{google\.serper\.dev/search}).once
    end

    it "makes HTTP request to OpenAI API" do
      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).at_least_once
    end

    it "includes summarize_search_results function" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          body["tools"]&.any? { |tool| tool["function"]["name"] == "summarize_search_results" }
        }
        .at_least_once
    end

    it "updates agent log with summary" do
      result = subject.perform

      expect(subject.agent_log.extra_data["summary"]).to be_present
      expect(subject.agent_log.extra_data["summary"]).to include("Pilot Iroshizuku Kon-peki")
      expect(result).to eq(subject.agent_log.extra_data["summary"])
    end

    it "approves the agent log" do
      subject.perform

      expect(subject.agent_log.reload.state).to eq("approved")
    end

    it "returns the summary" do
      result = subject.perform

      expect(result).to be_a(String)
      expect(result).to include("Pilot Iroshizuku Kon-peki")
      expect(result).to include("deep azure blue")
    end

    it "updates agent log transcript" do
      subject.perform

      transcript = subject.agent_log.transcript
      expect(transcript).to be_an(Array)
      expect(transcript.length).to be >= 3
      expect(transcript.first["role"]).to eq("system")
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

  describe "data formatting" do
    before do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: {
          "id" => "chatcmpl-test",
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
                    "id" => "call_test",
                    "type" => "function",
                    "function" => {
                      "name" => "summarize_search_results",
                      "arguments" => { "summary" => "Test summary" }.to_json
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => {
            "prompt_tokens" => 50,
            "completion_tokens" => 25,
            "total_tokens" => 75
          }
        }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "sends search term to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          body["messages"].any? do |msg|
            msg["content"]&.include?(
              "The search was done for the following search term: #{search_term}"
            )
          end
        }
        .at_least_once
    end

    it "sends JSON formatted search results to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          body["messages"].any? do |msg|
            msg["content"]&.include?("The search results are: #{normalized_search_results.to_json}")
          end
        }
        .at_least_once
    end

    it "handles empty search results" do
      stub_request(:post, %r{google\.serper\.dev/search}).to_return(
        status: 200,
        body: { "organic" => [] }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
      expected_empty = { "items" => [], "searchInformation" => { "totalResults" => "" } }
      summarizer = described_class.new(search_term, parent_agent_log: parent_agent_log)

      summarizer.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          body["messages"].any? do |msg|
            msg["content"]&.include?("The search results are: #{expected_empty.to_json}")
          end
        }
        .at_least_once
    end

    it "handles special characters in search term" do
      special_search_term = "Mont Blanc Nightfire Red & Blue ink"
      summarizer = described_class.new(special_search_term, parent_agent_log: parent_agent_log)

      summarizer.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          body["messages"].any? do |msg|
            msg["content"]&.include?(
              "The search was done for the following search term: #{special_search_term}"
            )
          end
        }
        .at_least_once
    end
  end

  describe "error handling" do
    context "when OpenAI API returns 500 error" do
      before do
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
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: "not valid json",
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises a parsing error" do
        expect { subject.perform }.to raise_error(RubyLLM::Error)
      end
    end

    context "when OpenAI returns unexpected response format" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-test",
            "object" => "chat.completion",
            "created" => 1_677_652_288,
            "model" => "gpt-4.1-mini",
            "choices" => [
              {
                "index" => 0,
                "message" => {
                  "role" => "assistant",
                  "content" => "This is a regular response without tool calls"
                },
                "finish_reason" => "stop"
              }
            ],
            "usage" => {
              "prompt_tokens" => 50,
              "completion_tokens" => 25,
              "total_tokens" => 75
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles response without tool calls gracefully" do
        expect { subject.perform }.not_to raise_error
      end
    end

    context "when function arguments are malformed" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-test",
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
                      "id" => "call_test",
                      "type" => "function",
                      "function" => {
                        "name" => "summarize_search_results",
                        "arguments" => "invalid json"
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 50,
              "completion_tokens" => 25,
              "total_tokens" => 75
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles malformed function arguments" do
        expect { subject.perform }.to raise_error(JSON::ParserError)
      end
    end

    context "when Google Search fails" do
      before do
        stub_request(:post, %r{google\.serper\.dev/search}).to_return(
          status: 500,
          body: "Internal Server Error"
        )
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-test",
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
                      "id" => "call_test",
                      "type" => "function",
                      "function" => {
                        "name" => "summarize_search_results",
                        "arguments" => {
                          "summary" => "Search failed, no results available."
                        }.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 50,
              "completion_tokens" => 25,
              "total_tokens" => 75
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "passes the error to the LLM and still returns a summary" do
        result = subject.perform

        expect(result).to be_a(String)
        expect(WebMock).to have_requested(
          :post,
          "https://api.openai.com/v1/chat/completions"
        ).with { |req|
          body = JSON.parse(req.body)
          body["messages"].any? { |msg| msg["content"]&.include?("Internal Server Error") }
        }
      end
    end
  end

  describe "integration scenarios" do
    context "complete summarization workflow" do
      before do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-comprehensive",
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
                      "id" => "call_comprehensive",
                      "type" => "function",
                      "function" => {
                        "name" => "summarize_search_results",
                        "arguments" => {
                          "summary" =>
                            "Found 2,450 results for 'Pilot Iroshizuku Kon-peki ink', indicating this is a well-known product. Pilot Iroshizuku Kon-peki is a popular deep azure blue fountain pen ink praised for its beautiful color and good flow characteristics. The search results show consistent positive reviews and comparisons with other blue inks. Alternative names found include 'Deep Azure Blue' and 'Kon-peki Blue'. This appears to be a legitimate, well-regarded fountain pen ink product."
                        }.to_json
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
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "completes full summarization workflow" do
        summarizer = described_class.new(search_term, parent_agent_log: parent_agent_log)

        result = summarizer.perform

        expect(result).to include("2,450 results")
        expect(result).to include("well-known product")
        expect(result).to include("deep azure blue")
        expect(result).to include("Alternative names")
        expect(result).to include("Deep Azure Blue")

        # Check agent log is properly updated
        expect(summarizer.agent_log.extra_data["summary"]).to eq(result)
        expect(summarizer.agent_log.state).to eq("approved")
        expect(summarizer.agent_log.owner).to eq(parent_agent_log)
        expect(summarizer.agent_log.name).to eq("GoogleSearchSummarizer")
      end
    end

    context "low results scenario" do
      let(:low_results) do
        {
          "organic" => [
            {
              "title" => "Obscure Ink Brand XYZ",
              "link" => "https://example.com/obscure-ink",
              "snippet" => "Limited information about this rare ink."
            }
          ],
          "searchInformation" => {
            "totalResults" => "3"
          }
        }
      end

      before do
        stub_request(:post, %r{google\.serper\.dev/search}).to_return(
          status: 200,
          body: low_results.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: {
            "id" => "chatcmpl-low-results",
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
                      "id" => "call_low_results",
                      "type" => "function",
                      "function" => {
                        "name" => "summarize_search_results",
                        "arguments" => {
                          "summary" =>
                            "Found only 3 results for 'Obscure Ink Brand XYZ', which is a very low number of results. This suggests the search term may not refer to a well-known or widely available product. Limited information is available about this ink brand."
                        }.to_json
                      }
                    }
                  ]
                },
                "finish_reason" => "tool_calls"
              }
            ],
            "usage" => {
              "prompt_tokens" => 60,
              "completion_tokens" => 30,
              "total_tokens" => 90
            }
          }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "handles low result count scenarios" do
        summarizer =
          described_class.new("Obscure Ink Brand XYZ", parent_agent_log: parent_agent_log)

        result = summarizer.perform

        expect(result).to include("only 3 results")
        expect(result).to include("very low number")
        expect(result).to include("may not refer to a well-known")
      end
    end
  end

  describe "tool" do
    it "uses SummarizeSearchResults tool" do
      tool = described_class::SummarizeSearchResults.new
      expect(tool.name).to eq("summarize_search_results")
      expect(tool.description).to eq("Summarize the search results")
    end

    it "halts with the summary" do
      tool = described_class::SummarizeSearchResults.new
      result = tool.call(summary: "Test summary")

      expect(result).to be_a(RubyLLM::Tool::Halt)
      expect(result.content).to eq("Test summary")
    end
  end
end
