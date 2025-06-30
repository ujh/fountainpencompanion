require "rails_helper"

describe InkSimilaritySearch do
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

      include InkSimilaritySearch

      def call_function(name, arguments)
        instance_exec(arguments, &self.class.get_functions[name][:block])
      end

      def functions
        self.class.get_functions
      end
    end
  end

  let(:test_instance) { test_class.new }
  let(:macro_cluster_1) do
    double(
      "MacroCluster",
      id: 1,
      name: "Pilot Iroshizuku Kon-peki",
      synonyms: ["Pilot Kon-peki", "Iroshizuku Blue"],
      color: "#1E3A8A"
    )
  end

  let(:macro_cluster_2) do
    double(
      "MacroCluster",
      id: 2,
      name: "Sailor Sei-boku",
      synonyms: ["Sailor Blue", "Sei-boku"],
      color: nil
    )
  end

  let(:macro_cluster_3) do
    double(
      "MacroCluster",
      id: 3,
      name: "Diamine Oxford Blue",
      synonyms: ["Oxford Blue"],
      color: "#003366"
    )
  end

  describe "#agent_log" do
    it "raises NotImplementedError" do
      expect { test_instance.agent_log }.to raise_error(NotImplementedError)
    end
  end

  describe "when included" do
    it "defines ink_similarity_search function" do
      expect(test_instance.functions).to have_key(:ink_similarity_search)
    end

    it "defines ink_full_text_search function" do
      expect(test_instance.functions).to have_key(:ink_full_text_search)
    end

    describe "ink_similarity_search function" do
      let(:search_result_1) { double("SearchResult", cluster: macro_cluster_1, distance: 0.15) }

      let(:search_result_2) { double("SearchResult", cluster: macro_cluster_2, distance: 0.23) }

      let(:search_result_3) { double("SearchResult", cluster: macro_cluster_3, distance: 0.31) }

      before do
        allow(MacroCluster).to receive(:embedding_search).and_return(
          [search_result_1, search_result_2, search_result_3]
        )
      end

      it "has correct description" do
        function_def = test_instance.functions[:ink_similarity_search]
        expect(function_def[:description]).to eq(
          "Find the 20 most similar ink clusters by cosine distance"
        )
      end

      it "has correct arguments schema" do
        function_def = test_instance.functions[:ink_similarity_search]
        expect(function_def[:args]).to eq({ search_string: { type: "string" } })
      end

      it "calls MacroCluster.embedding_search with search string" do
        test_instance.call_function(:ink_similarity_search, { search_string: "blue ink" })

        expect(MacroCluster).to have_received(:embedding_search).with("blue ink")
      end

      it "limits results to 20 items" do
        # Create 25 mock results
        mock_results =
          25.times.map do |i|
            cluster = double("Cluster#{i}", id: i, name: "Ink #{i}", synonyms: [], color: nil)
            double("SearchResult", cluster: cluster, distance: 0.1 + (i * 0.01))
          end

        allow(MacroCluster).to receive(:embedding_search).and_return(mock_results)

        result = test_instance.call_function(:ink_similarity_search, { search_string: "test" })

        expect(result.length).to eq(20)
      end

      it "returns formatted cluster data with distances" do
        result = test_instance.call_function(:ink_similarity_search, { search_string: "blue ink" })

        expect(result).to eq(
          [
            {
              id: 1,
              name: "Pilot Iroshizuku Kon-peki",
              distance: 0.15,
              synonyms: ["Pilot Kon-peki", "Iroshizuku Blue"],
              color: "#1E3A8A"
            },
            {
              id: 2,
              name: "Sailor Sei-boku",
              distance: 0.23,
              synonyms: ["Sailor Blue", "Sei-boku"]
            },
            {
              id: 3,
              name: "Diamine Oxford Blue",
              distance: 0.31,
              synonyms: ["Oxford Blue"],
              color: "#003366"
            }
          ]
        )
      end

      it "excludes color when not present" do
        result = test_instance.call_function(:ink_similarity_search, { search_string: "blue ink" })

        cluster_without_color = result.find { |c| c[:id] == 2 }
        expect(cluster_without_color).not_to have_key(:color)
      end

      it "includes color when present" do
        result = test_instance.call_function(:ink_similarity_search, { search_string: "blue ink" })

        cluster_with_color = result.find { |c| c[:id] == 1 }
        expect(cluster_with_color[:color]).to eq("#1E3A8A")
      end

      it "handles empty search results" do
        allow(MacroCluster).to receive(:embedding_search).and_return([])

        result =
          test_instance.call_function(:ink_similarity_search, { search_string: "nonexistent ink" })

        expect(result).to eq([])
      end

      it "handles clusters with empty synonyms" do
        cluster_with_empty_synonyms =
          double("MacroCluster", id: 4, name: "Test Ink", synonyms: [], color: nil)
        search_result = double("SearchResult", cluster: cluster_with_empty_synonyms, distance: 0.5)

        allow(MacroCluster).to receive(:embedding_search).and_return([search_result])

        result = test_instance.call_function(:ink_similarity_search, { search_string: "test" })

        expect(result.first[:synonyms]).to eq([])
      end

      it "handles blank color strings" do
        cluster_with_blank_color =
          double("MacroCluster", id: 5, name: "Test Ink", synonyms: ["Test"], color: "")
        search_result = double("SearchResult", cluster: cluster_with_blank_color, distance: 0.5)

        allow(MacroCluster).to receive(:embedding_search).and_return([search_result])

        result = test_instance.call_function(:ink_similarity_search, { search_string: "test" })

        expect(result.first).not_to have_key(:color)
      end
    end

    describe "ink_full_text_search function" do
      before do
        allow(MacroCluster).to receive(:full_text_search).and_return(
          [macro_cluster_1, macro_cluster_2, macro_cluster_3]
        )
      end

      it "has correct description" do
        function_def = test_instance.functions[:ink_full_text_search]
        expect(function_def[:description]).to eq(
          "Fallback search, when results using similarity search inconclusive. Finds inks by full text search"
        )
      end

      it "has correct arguments schema" do
        function_def = test_instance.functions[:ink_full_text_search]
        expect(function_def[:args]).to eq({ search_string: { type: "string" } })
      end

      it "calls MacroCluster.full_text_search with search string" do
        test_instance.call_function(:ink_full_text_search, { search_string: "pilot blue" })

        expect(MacroCluster).to have_received(:full_text_search).with("pilot blue")
      end

      it "returns formatted cluster data without distances" do
        result = test_instance.call_function(:ink_full_text_search, { search_string: "pilot blue" })

        expect(result).to eq(
          [
            {
              id: 1,
              name: "Pilot Iroshizuku Kon-peki",
              synonyms: ["Pilot Kon-peki", "Iroshizuku Blue"],
              color: "#1E3A8A"
            },
            { id: 2, name: "Sailor Sei-boku", synonyms: ["Sailor Blue", "Sei-boku"] },
            { id: 3, name: "Diamine Oxford Blue", synonyms: ["Oxford Blue"], color: "#003366" }
          ]
        )
      end

      it "excludes color when not present" do
        result = test_instance.call_function(:ink_full_text_search, { search_string: "sailor" })

        cluster_without_color = result.find { |c| c[:id] == 2 }
        expect(cluster_without_color).not_to have_key(:color)
      end

      it "includes color when present" do
        result = test_instance.call_function(:ink_full_text_search, { search_string: "pilot" })

        cluster_with_color = result.find { |c| c[:id] == 1 }
        expect(cluster_with_color[:color]).to eq("#1E3A8A")
      end

      it "handles empty search results" do
        allow(MacroCluster).to receive(:full_text_search).and_return([])

        result =
          test_instance.call_function(:ink_full_text_search, { search_string: "nonexistent ink" })

        expect(result).to eq([])
      end

      it "handles clusters with empty synonyms" do
        cluster_with_empty_synonyms =
          double("MacroCluster", id: 4, name: "Test Ink", synonyms: [], color: nil)

        allow(MacroCluster).to receive(:full_text_search).and_return([cluster_with_empty_synonyms])

        result = test_instance.call_function(:ink_full_text_search, { search_string: "test" })

        expect(result.first[:synonyms]).to eq([])
      end

      it "handles blank color strings" do
        cluster_with_blank_color =
          double("MacroCluster", id: 5, name: "Test Ink", synonyms: ["Test"], color: "")

        allow(MacroCluster).to receive(:full_text_search).and_return([cluster_with_blank_color])

        result = test_instance.call_function(:ink_full_text_search, { search_string: "test" })

        expect(result.first).not_to have_key(:color)
      end

      it "does not include distance in results" do
        result = test_instance.call_function(:ink_full_text_search, { search_string: "test" })

        result.each { |cluster_data| expect(cluster_data).not_to have_key(:distance) }
      end
    end

    describe "integration scenarios" do
      it "both functions can be called on same instance" do
        # Mock both search methods
        allow(MacroCluster).to receive(:embedding_search).and_return(
          [double("SearchResult", cluster: macro_cluster_1, distance: 0.1)]
        )
        allow(MacroCluster).to receive(:full_text_search).and_return([macro_cluster_2])

        similarity_result =
          test_instance.call_function(:ink_similarity_search, { search_string: "blue" })
        full_text_result =
          test_instance.call_function(:ink_full_text_search, { search_string: "blue" })

        expect(similarity_result.first[:id]).to eq(1)
        expect(similarity_result.first).to have_key(:distance)

        expect(full_text_result.first[:id]).to eq(2)
        expect(full_text_result.first).not_to have_key(:distance)
      end
    end

    describe "error handling" do
      it "handles MacroCluster.embedding_search exceptions" do
        allow(MacroCluster).to receive(:embedding_search).and_raise(StandardError, "Search failed")

        expect {
          test_instance.call_function(:ink_similarity_search, { search_string: "test" })
        }.to raise_error(StandardError, "Search failed")
      end

      it "handles MacroCluster.full_text_search exceptions" do
        allow(MacroCluster).to receive(:full_text_search).and_raise(StandardError, "Search failed")

        expect {
          test_instance.call_function(:ink_full_text_search, { search_string: "test" })
        }.to raise_error(StandardError, "Search failed")
      end
    end
  end
end
