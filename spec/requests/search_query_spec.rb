require "rails_helper"

describe "Search query handling" do
  describe "GET /inks" do
    it "treats an array q as no search" do
      get "/inks?q[]=blue"
      expect(response).to redirect_to(brands_path)
    end

    it "treats a blank q as no search" do
      get "/inks", params: { q: "   " }
      expect(response).to redirect_to(brands_path)
    end

    it "truncates over-long queries" do
      expect(MacroCluster).to receive(:full_text_search).with(
        "a" * SearchQuery::MAX_LENGTH
      ).and_return([])
      get "/inks", params: { q: "a" * 500 }
      expect(response).to have_http_status(:ok)
    end

    it "renders the query in the page" do
      allow(MacroCluster).to receive(:full_text_search).and_return([])
      get "/inks", params: { q: "<b>blue</b>" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("&lt;b&gt;blue&lt;/b&gt;")
      expect(response.body).not_to include("<b>blue</b>")
    end
  end

  describe "GET /pen_models" do
    it "treats an array q as no search and does not call the embedding service" do
      expect(EmbeddingsClient).not_to receive(:new)
      get "/pen_models?q[]=eco"
      expect(response).to have_http_status(:ok)
    end

    it "truncates over-long queries before embedding" do
      expect(Pens::Model).to receive(:embedding_search).with(
        "a" * SearchQuery::MAX_LENGTH
      ).and_return([])
      get "/pen_models", params: { q: "a" * 500 }
      expect(response).to have_http_status(:ok)
    end

    it "renders without a query and without a search results title" do
      expect(EmbeddingsClient).not_to receive(:new)
      get "/pen_models"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Search results for")
    end
  end
end
