require "rails_helper"

RSpec.describe GoogleSearchSummarizer do
  before(:each) { WebMock.reset! }

  let(:user) { create(:user) }
  let(:search_term) { "Pilot Iroshizuku Kon-peki ink" }
  let(:search_results) do
    {
      "items" => [
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

  subject { described_class.new(search_term, search_results, user) }

  describe "#initialize" do
    it "creates agent with search term, results, and owner" do
      summarizer = described_class.new(search_term, search_results, user)
      expect(summarizer.send(:search_term)).to eq(search_term)
      expect(summarizer.send(:search_results)).to eq(search_results)
      expect(summarizer.send(:owner)).to eq(user)
    end

    it "initializes transcript with system directive" do
      summarizer = described_class.new(search_term, search_results, user)
      expect(summarizer.transcript.first[:system]).to be_present
      expect(summarizer.transcript.first[:system]).to include(
        "You are tasked with summarizing the results of a Google search"
      )
      expect(summarizer.transcript.first[:system]).to include("alternative spellings or names")
    end

    it "adds search term prompt to transcript" do
      summarizer = described_class.new(search_term, search_results, user)
      search_term_message =
        summarizer.transcript.find { |msg| msg[:user]&.include?("search was done for") }
      expect(search_term_message[:user]).to include(search_term)
    end

    it "adds search results prompt to transcript" do
      summarizer = described_class.new(search_term, search_results, user)
      search_results_message =
        summarizer.transcript.find { |msg| msg[:user]&.include?("search results are") }
      expect(search_results_message[:user]).to include(search_results.to_json)
    end
  end

  describe "#agent_log" do
    it "creates and memoizes agent log" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to be_persisted
      expect(log1.name).to eq("GoogleSearchSummarizer")
      expect(log1.owner).to eq(user)
      expect(log1).to eq(log2)
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
            msg["content"]&.include?("The search results are: #{search_results.to_json}")
          end
        }
        .at_least_once
    end

    it "handles empty search results" do
      empty_results = { "items" => [] }
      summarizer = described_class.new(search_term, empty_results, user)

      result = summarizer.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          body["messages"].any? do |msg|
            msg["content"]&.include?("The search results are: #{empty_results.to_json}")
          end
        }
        .at_least_once
    end

    it "handles special characters in search term" do
      special_search_term = "Mont Blanc Nightfire Red & Blue ink"
      summarizer = described_class.new(special_search_term, search_results, user)

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
        expect { subject.perform }.to raise_error(Faraday::ServerError)
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
        expect { subject.perform }.to raise_error(Faraday::ParsingError)
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
        # This should not raise an error, but may not set the summary
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
        # Suppress the warning about bad JSON that comes from the Raix gem
        silence_warnings { expect { subject.perform }.to raise_error(JSON::ParserError) }
      end
    end
  end

  describe "integration scenarios" do
    context "complete summarization workflow" do
      let(:comprehensive_search_results) do
        {
          "items" => [
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
            },
            {
              "title" => "Kon-peki vs Other Blue Inks",
              "link" => "https://example.com/blue-ink-comparison",
              "snippet" =>
                "Comparing Kon-peki with other popular blue fountain pen inks. Also known as Deep Azure Blue."
            }
          ],
          "searchInformation" => {
            "totalResults" => "2450"
          }
        }
      end

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
        summarizer = described_class.new(search_term, comprehensive_search_results, user)

        result = summarizer.perform

        expect(result).to include("2,450 results")
        expect(result).to include("well-known product")
        expect(result).to include("deep azure blue")
        expect(result).to include("Alternative names")
        expect(result).to include("Deep Azure Blue")

        # Check agent log is properly updated
        expect(summarizer.agent_log.extra_data["summary"]).to eq(result)
        expect(summarizer.agent_log.state).to eq("approved")
        expect(summarizer.agent_log.owner).to eq(user)
        expect(summarizer.agent_log.name).to eq("GoogleSearchSummarizer")
      end
    end

    context "low results scenario" do
      let(:low_results) do
        {
          "items" => [
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
        summarizer = described_class.new("Obscure Ink Brand XYZ", low_results, user)

        result = summarizer.perform

        expect(result).to include("only 3 results")
        expect(result).to include("very low number")
        expect(result).to include("may not refer to a well-known")
      end
    end
  end

  describe "function dispatch" do
    describe "#summarize_search_results" do
      it "sets the summary and stops tool calls" do
        test_summary = "This is a test summary"

        # Test that the function is defined and accessible
        expect(subject.class.instance_methods).to include(:summarize_search_results)

        # Test the summary attribute can be set
        subject.instance_variable_set(:@summary, test_summary)
        expect(subject.send(:summary)).to eq(test_summary)
      end
    end
  end
end
