require "rails_helper"

describe HistoriesController do
  describe "#calculate_diffs" do
    let(:controller) { described_class.new }

    context "with version containing only description changes" do
      let(:version) do
        double("version", changeset: { "description" => ["Old description", "New description"] })
      end

      it "returns a single diff entry with label 'Description'" do
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        result = controller.send(:calculate_diffs, version)

        expect(result).to eq([{ label: "Description", type: :text, diff: "formatted diff" }])
        expect(Differ).to have_received(:diff_by_word).with("New description", "Old description")
      end
    end

    context "with version containing only manual_brand_name changes" do
      let(:version) do
        double("version", changeset: { "manual_brand_name" => ["Old Brand", "New Brand"] })
      end

      it "returns a single diff entry with label 'Brand Name'" do
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        result = controller.send(:calculate_diffs, version)

        expect(result).to eq([{ label: "Brand Name", type: :text, diff: "formatted diff" }])
        expect(Differ).to have_received(:diff_by_word).with("New Brand", "Old Brand")
      end
    end

    context "with version containing only manual_line_name changes" do
      let(:version) do
        double("version", changeset: { "manual_line_name" => ["Old Line", "New Line"] })
      end

      it "returns a single diff entry with label 'Line Name'" do
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        result = controller.send(:calculate_diffs, version)

        expect(result).to eq([{ label: "Line Name", type: :text, diff: "formatted diff" }])
        expect(Differ).to have_received(:diff_by_word).with("New Line", "Old Line")
      end
    end

    context "with version containing only manual_ink_name changes" do
      let(:version) do
        double("version", changeset: { "manual_ink_name" => ["Old Ink", "New Ink"] })
      end

      it "returns a single diff entry with label 'Ink Name'" do
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        result = controller.send(:calculate_diffs, version)

        expect(result).to eq([{ label: "Ink Name", type: :text, diff: "formatted diff" }])
        expect(Differ).to have_received(:diff_by_word).with("New Ink", "Old Ink")
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
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        result = controller.send(:calculate_diffs, version)

        expect(result.length).to eq(3)
        expect(result.map { |e| e[:label] }).to eq(["Description", "Brand Name", "Ink Name"])
        expect(Differ).to have_received(:diff_by_word).exactly(3).times
      end
    end

    context "with version containing nil to string change" do
      let(:version) { double("version", changeset: { "manual_brand_name" => [nil, "New Brand"] }) }

      it "handles nil values by converting to string" do
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        controller.send(:calculate_diffs, version)

        expect(Differ).to have_received(:diff_by_word).with("New Brand", "")
      end
    end

    context "with version containing string to nil change" do
      let(:version) { double("version", changeset: { "manual_ink_name" => ["Old Ink", nil] }) }

      it "handles nil values by converting to string" do
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        controller.send(:calculate_diffs, version)

        expect(Differ).to have_received(:diff_by_word).with("", "Old Ink")
      end
    end

    context "with version containing no tracked field changes" do
      let(:version) { double("version", changeset: { "some_other_field" => %w[old new] }) }

      it "returns an empty array" do
        result = controller.send(:calculate_diffs, version)

        expect(result).to eq([])
      end
    end
  end
end
