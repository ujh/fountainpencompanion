require "rails_helper"

describe InkWebSearch do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      # Define class-level storage and method before including the concern
      @functions = {}

      def self.function(name, description, **args, &block)
        @functions[name] = { description: description, args: args, block: block }
      end

      def self.get_functions
        @functions
      end

      include InkWebSearch

      def call_function(name, arguments)
        instance_exec(arguments, &self.class.get_functions[name][:block])
      end

      def functions
        self.class.get_functions
      end
    end
  end

  let(:test_instance) { test_class.new }
  let(:mock_google_search) { double("GoogleSearch") }
  let(:mock_google_search_summarizer) { double("GoogleSearchSummarizer") }
  let(:mock_agent_log) { double("AgentLog") }
  let(:search_results) { %w[result1 result2 result3] }
  let(:search_summary) { "Summary of search results about fountain pen ink" }

  describe "#agent_log" do
    it "raises NotImplementedError" do
      expect { test_instance.agent_log }.to raise_error(NotImplementedError)
    end
  end

  describe "when included" do
    it "defines search_web function" do
      expect(test_instance.functions).to have_key(:search_web)
    end

    describe "search_web function" do
      before do
        allow(GoogleSearch).to receive(:new).and_return(mock_google_search)
        allow(mock_google_search).to receive(:perform).and_return(search_results)
        allow(GoogleSearchSummarizer).to receive(:new).and_return(mock_google_search_summarizer)
        allow(mock_google_search_summarizer).to receive(:perform).and_return(search_summary)
        allow(test_instance).to receive(:agent_log).and_return(mock_agent_log)
      end

      it "has correct description" do
        function_def = test_instance.functions[:search_web]
        expect(function_def[:description]).to eq("Search the web")
      end

      it "has correct arguments schema" do
        function_def = test_instance.functions[:search_web]
        expect(function_def[:args]).to eq({ search_query: { type: "string" } })
      end

      it "appends ' ink' to the search query" do
        test_instance.call_function(:search_web, { search_query: "pilot iroshizuku" })

        expect(GoogleSearch).to have_received(:new).with("pilot iroshizuku ink")
      end

      it "creates GoogleSearch instance with modified query" do
        test_instance.call_function(:search_web, { search_query: "fountain pen blue" })

        expect(GoogleSearch).to have_received(:new).with("fountain pen blue ink")
      end

      it "calls perform on GoogleSearch instance" do
        test_instance.call_function(:search_web, { search_query: "test query" })

        expect(mock_google_search).to have_received(:perform)
      end

      it "creates GoogleSearchSummarizer with correct parameters" do
        test_instance.call_function(:search_web, { search_query: "diamine" })

        expect(GoogleSearchSummarizer).to have_received(:new).with(
          "diamine ink",
          search_results,
          mock_agent_log
        )
      end

      it "calls perform on GoogleSearchSummarizer instance" do
        test_instance.call_function(:search_web, { search_query: "test" })

        expect(mock_google_search_summarizer).to have_received(:perform)
      end

      it "returns formatted search results string" do
        result = test_instance.call_function(:search_web, { search_query: "sailor" })

        expected_result = "The search results for 'sailor ink' are:\n #{search_summary}"
        expect(result).to eq(expected_result)
      end

      context "with different search queries" do
        it "handles single word queries" do
          result = test_instance.call_function(:search_web, { search_query: "waterman" })

          expect(GoogleSearch).to have_received(:new).with("waterman ink")
          expect(result).to include("The search results for 'waterman ink' are:")
        end

        it "handles multi-word queries" do
          result =
            test_instance.call_function(:search_web, { search_query: "montblanc mystery black" })

          expect(GoogleSearch).to have_received(:new).with("montblanc mystery black ink")
          expect(result).to include("The search results for 'montblanc mystery black ink' are:")
        end

        it "handles queries with special characters" do
          result = test_instance.call_function(:search_web, { search_query: "pilot iro-shizuku" })

          expect(GoogleSearch).to have_received(:new).with("pilot iro-shizuku ink")
          expect(result).to include("The search results for 'pilot iro-shizuku ink' are:")
        end

        it "handles empty search query" do
          result = test_instance.call_function(:search_web, { search_query: "" })

          expect(GoogleSearch).to have_received(:new).with(" ink")
          expect(result).to include("The search results for ' ink' are:")
        end

        it "handles queries with leading/trailing whitespace" do
          result = test_instance.call_function(:search_web, { search_query: "  pilot  " })

          expect(GoogleSearch).to have_received(:new).with("  pilot   ink")
          expect(result).to include("The search results for '  pilot   ink' are:")
        end
      end

      context "with different search results" do
        it "handles empty search results" do
          allow(mock_google_search).to receive(:perform).and_return([])

          result = test_instance.call_function(:search_web, { search_query: "test" })

          expect(GoogleSearchSummarizer).to have_received(:new).with("test ink", [], mock_agent_log)
          expect(result).to include("The search results for 'test ink' are:")
        end

        it "handles single search result" do
          single_result = ["single result"]
          allow(mock_google_search).to receive(:perform).and_return(single_result)

          test_instance.call_function(:search_web, { search_query: "test" })

          expect(GoogleSearchSummarizer).to have_received(:new).with(
            "test ink",
            single_result,
            mock_agent_log
          )
        end

        it "handles multiple search results" do
          multiple_results = %w[result1 result2 result3 result4 result5]
          allow(mock_google_search).to receive(:perform).and_return(multiple_results)

          test_instance.call_function(:search_web, { search_query: "test" })

          expect(GoogleSearchSummarizer).to have_received(:new).with(
            "test ink",
            multiple_results,
            mock_agent_log
          )
        end
      end

      context "with different search summaries" do
        it "handles short summary" do
          short_summary = "Brief summary"
          allow(mock_google_search_summarizer).to receive(:perform).and_return(short_summary)

          result = test_instance.call_function(:search_web, { search_query: "test" })

          expect(result).to eq("The search results for 'test ink' are:\n #{short_summary}")
        end

        it "handles long summary" do
          long_summary =
            "This is a very long summary that contains detailed information about fountain pen inks and their characteristics, including color properties, flow characteristics, and user reviews."
          allow(mock_google_search_summarizer).to receive(:perform).and_return(long_summary)

          result = test_instance.call_function(:search_web, { search_query: "test" })

          expect(result).to eq("The search results for 'test ink' are:\n #{long_summary}")
        end

        it "handles summary with special characters" do
          special_summary = "Summary with émojis 🖋️ and spëcial chars & symbols"
          allow(mock_google_search_summarizer).to receive(:perform).and_return(special_summary)

          result = test_instance.call_function(:search_web, { search_query: "test" })

          expect(result).to eq("The search results for 'test ink' are:\n #{special_summary}")
        end

        it "handles empty summary" do
          allow(mock_google_search_summarizer).to receive(:perform).and_return("")

          result = test_instance.call_function(:search_web, { search_query: "test" })

          expect(result).to eq("The search results for 'test ink' are:\n ")
        end
      end

      describe "integration flow" do
        it "follows the complete flow from query to result" do
          # Setup the complete chain
          query = "noodlers black"
          modified_query = "noodlers black ink"
          mock_results = %w[result1 result2]
          mock_summary = "Comprehensive summary"

          allow(GoogleSearch).to receive(:new).with(modified_query).and_return(mock_google_search)
          allow(mock_google_search).to receive(:perform).and_return(mock_results)
          allow(GoogleSearchSummarizer).to receive(:new).with(
            modified_query,
            mock_results,
            mock_agent_log
          ).and_return(mock_google_search_summarizer)
          allow(mock_google_search_summarizer).to receive(:perform).and_return(mock_summary)

          result = test_instance.call_function(:search_web, { search_query: query })

          # Verify the complete chain
          expect(GoogleSearch).to have_received(:new).with(modified_query)
          expect(mock_google_search).to have_received(:perform)
          expect(GoogleSearchSummarizer).to have_received(:new).with(
            modified_query,
            mock_results,
            mock_agent_log
          )
          expect(mock_google_search_summarizer).to have_received(:perform)
          expect(result).to eq("The search results for '#{modified_query}' are:\n #{mock_summary}")
        end
      end

      describe "error handling" do
        it "propagates GoogleSearch instantiation errors" do
          allow(GoogleSearch).to receive(:new).and_raise(
            StandardError,
            "Search service unavailable"
          )

          expect {
            test_instance.call_function(:search_web, { search_query: "test" })
          }.to raise_error(StandardError, "Search service unavailable")
        end

        it "propagates GoogleSearch perform errors" do
          allow(mock_google_search).to receive(:perform).and_raise(StandardError, "API error")

          expect {
            test_instance.call_function(:search_web, { search_query: "test" })
          }.to raise_error(StandardError, "API error")
        end

        it "propagates GoogleSearchSummarizer instantiation errors" do
          allow(GoogleSearchSummarizer).to receive(:new).and_raise(
            StandardError,
            "Summarizer error"
          )

          expect {
            test_instance.call_function(:search_web, { search_query: "test" })
          }.to raise_error(StandardError, "Summarizer error")
        end

        it "propagates GoogleSearchSummarizer perform errors" do
          allow(mock_google_search_summarizer).to receive(:perform).and_raise(
            StandardError,
            "Summarization failed"
          )

          expect {
            test_instance.call_function(:search_web, { search_query: "test" })
          }.to raise_error(StandardError, "Summarization failed")
        end

        it "propagates agent_log errors" do
          allow(test_instance).to receive(:agent_log).and_raise(StandardError, "Agent log error")

          expect {
            test_instance.call_function(:search_web, { search_query: "test" })
          }.to raise_error(StandardError, "Agent log error")
        end

        context "when agent_log raises NotImplementedError" do
          before do
            # Don't mock agent_log, let it raise NotImplementedError naturally
            allow(test_instance).to receive(:agent_log).and_call_original
          end

          it "propagates the NotImplementedError" do
            expect {
              test_instance.call_function(:search_web, { search_query: "test" })
            }.to raise_error(NotImplementedError)
          end
        end
      end

      describe "parameter validation" do
        it "handles missing search_query parameter" do
          result = test_instance.call_function(:search_web, {})

          expect(GoogleSearch).to have_received(:new).with(" ink")
          expect(result).to include("The search results for ' ink' are:")
        end

        it "handles nil search_query parameter" do
          result = test_instance.call_function(:search_web, { search_query: nil })

          expect(GoogleSearch).to have_received(:new).with(" ink")
          expect(result).to include("The search results for ' ink' are:")
        end
      end
    end
  end
end
