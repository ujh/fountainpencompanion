require "rails_helper"

describe HistoriesController do
  describe "GET /inks/:ink_id/history" do
    it "shows the history of the ink" do
      brand = create(:brand_cluster, name: "Pelikan")
      ink = create(:macro_cluster, brand_cluster: brand, manual_ink_name: "Blue Black")

      get "/inks/#{ink.id}/history"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("History for #{ink.name}")
    end

    it "shows a word diff of a description change" do
      ink =
        create(
          :macro_cluster,
          brand_cluster: create(:brand_cluster),
          description: "A pale blue ink"
        )
      ink.update!(description: "A deep blue ink")

      get "/inks/#{ink.id}/history"

      expect(response.body).to include(
        'A <del class="differ">pale</del><ins class="differ">deep</ins> blue ink'
      )
    end

    it "returns 404 when the ink does not exist" do
      get "/inks/0-deleted-ink/history"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /brands/:brand_id/history" do
    it "shows the history of the brand" do
      brand = create(:brand_cluster, name: "Pelikan")

      get "/brands/#{brand.id}/history"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("History for Pelikan")
    end

    it "returns 404 when the brand does not exist" do
      get "/brands/0-deleted-brand/history"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "#calculate_diffs" do
    let(:controller) { described_class.new }

    context "with version containing only description changes" do
      let(:version) do
        double("version", changeset: { "description" => ["Old description", "New description"] })
      end

      it "returns a single diff entry with label 'Description'" do
        result = controller.send(:calculate_diffs, version)

        expect(result).to eq(
          [
            {
              label: "Description",
              type: :text,
              diff: '<del class="differ">Old</del><ins class="differ">New</ins> description'
            }
          ]
        )
        expect(result.first[:diff]).to be_html_safe
      end
    end

    context "with version containing only manual_brand_name changes" do
      let(:version) do
        double("version", changeset: { "manual_brand_name" => ["Old Brand", "New Brand"] })
      end

      it "returns a single diff entry with label 'Brand Name'" do
        result = controller.send(:calculate_diffs, version)

        expect(result).to eq(
          [
            {
              label: "Brand Name",
              type: :text,
              diff: '<del class="differ">Old</del><ins class="differ">New</ins> Brand'
            }
          ]
        )
      end
    end

    context "with version containing only manual_line_name changes" do
      let(:version) do
        double("version", changeset: { "manual_line_name" => ["Old Line", "New Line"] })
      end

      it "returns a single diff entry with label 'Line Name'" do
        result = controller.send(:calculate_diffs, version)

        expect(result).to eq(
          [
            {
              label: "Line Name",
              type: :text,
              diff: '<del class="differ">Old</del><ins class="differ">New</ins> Line'
            }
          ]
        )
      end
    end

    context "with version containing only manual_ink_name changes" do
      let(:version) do
        double("version", changeset: { "manual_ink_name" => ["Old Ink", "New Ink"] })
      end

      it "returns a single diff entry with label 'Ink Name'" do
        result = controller.send(:calculate_diffs, version)

        expect(result).to eq(
          [
            {
              label: "Ink Name",
              type: :text,
              diff: '<del class="differ">Old</del><ins class="differ">New</ins> Ink'
            }
          ]
        )
      end
    end

    context "with version containing multiple field changes" do
      let(:version) do
        double(
          "version",
          changeset: {
            "description" => ["Old desc", "New desc"],
            "manual_brand_name" => ["Old Brand", "New Brand"],
            "manual_ink_name" => ["Old Ink", "New Ink"]
          }
        )
      end

      it "returns diff entries for all changed fields in order" do
        result = controller.send(:calculate_diffs, version)

        expect(result.map { |e| [e[:label], e[:diff]] }).to eq(
          [
            ["Description", '<del class="differ">Old</del><ins class="differ">New</ins> desc'],
            ["Brand Name", '<del class="differ">Old</del><ins class="differ">New</ins> Brand'],
            ["Ink Name", '<del class="differ">Old</del><ins class="differ">New</ins> Ink']
          ]
        )
      end
    end

    context "with version containing nil to string change" do
      let(:version) { double("version", changeset: { "manual_brand_name" => [nil, "New Brand"] }) }

      it "handles nil values by converting to string" do
        result = controller.send(:calculate_diffs, version)

        expect(result.first[:diff]).to eq('<ins class="differ">New Brand</ins>')
      end
    end

    context "with version containing string to nil change" do
      let(:version) { double("version", changeset: { "manual_ink_name" => ["Old Ink", nil] }) }

      it "handles nil values by converting to string" do
        result = controller.send(:calculate_diffs, version)

        expect(result.first[:diff]).to eq('<del class="differ">Old Ink</del>')
      end
    end

    context "with version containing no tracked field changes" do
      let(:version) { double("version", changeset: { "some_other_field" => %w[old new] }) }

      it "returns an empty array" do
        result = controller.send(:calculate_diffs, version)

        expect(result).to eq([])
      end
    end

    context "with HTML in changeset values (XSS regression)" do
      let(:version) do
        double("version", changeset: { "description" => ["safe old", "<script>alert(1)</script>"] })
      end

      it "HTML-escapes the values before diffing them" do
        result = controller.send(:calculate_diffs, version)

        expect(result.first[:diff]).to eq(
          '<del class="differ">safe old</del><ins class="differ">&lt;script&gt;alert(1)&lt;/script&gt;</ins>'
        )
      end
    end

    context "with a description too long to compare" do
      let(:long_description) { (["word"] * 1_501).join(" ") }
      let(:version) do
        double("version", changeset: { "description" => ["Old description", long_description] })
      end

      it "shows a message instead of the diff" do
        result = controller.send(:calculate_diffs, version)

        expect(result.first[:diff]).to eq('<em class="text-muted">Too long to compare.</em>')
      end
    end

    context "with line_name_is_empty change" do
      let(:object) { double("object", automatic_line_name: "<line> Iroshizuku") }
      let(:version) { double("version", changeset: { "line_name_is_empty" => [true, false] }) }

      before { allow(controller).to receive(:object).and_return(object) }

      it "HTML-escapes the automatic_line_name and labels it 'Line Name'" do
        result = controller.send(:calculate_diffs, version)

        expect(result).to eq(
          [
            {
              label: "Line Name",
              type: :text,
              diff: '<ins class="differ">&lt;line&gt; Iroshizuku</ins>'
            }
          ]
        )
      end
    end
  end
end
