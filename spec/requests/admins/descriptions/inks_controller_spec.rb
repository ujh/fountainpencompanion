require "rails_helper"

describe Admins::Descriptions::InksController do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe "GET /admins/descriptions/inks" do
    context "when not authenticated" do
      it "redirects to login" do
        get "/admins/descriptions/inks"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as regular user" do
      before { sign_in(regular_user) }

      it "redirects to login" do
        get "/admins/descriptions/inks"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as admin" do
      before { sign_in(admin) }

      context "with no versions" do
        it "renders successfully" do
          get "/admins/descriptions/inks"
          expect(response).to be_successful
        end

        it "assigns empty versions collection" do
          get "/admins/descriptions/inks"
          expect(assigns(:versions)).to be_empty
        end
      end

      context "with macro cluster versions" do
        let(:macro_cluster) { create(:macro_cluster) }

        let!(:description_version) do
          create_version(
            item_type: "MacroCluster",
            item_id: macro_cluster.id,
            object_changes: { "description" => [nil, "First ink description"] }.to_yaml,
            created_at: 2.days.ago
          )
        end

        let!(:brand_name_version) do
          create_version(
            item_type: "MacroCluster",
            item_id: macro_cluster.id,
            object_changes: { "manual_brand_name" => [nil, "Pilot"] }.to_yaml,
            created_at: 1.day.ago
          )
        end

        let!(:line_name_version) do
          create_version(
            item_type: "MacroCluster",
            item_id: macro_cluster.id,
            object_changes: { "manual_line_name" => [nil, "Iroshizuku"] }.to_yaml,
            created_at: 12.hours.ago
          )
        end

        let!(:ink_name_version) do
          create_version(
            item_type: "MacroCluster",
            item_id: macro_cluster.id,
            object_changes: { "manual_ink_name" => [nil, "Kon-peki"] }.to_yaml,
            created_at: 6.hours.ago
          )
        end

        let!(:non_tracked_version) do
          create_version(
            item_type: "MacroCluster",
            item_id: macro_cluster.id,
            object_changes: { "name" => ["Old ink name", "New ink name"] }.to_yaml,
            created_at: 1.hour.ago
          )
        end

        let!(:non_macro_cluster_version) do
          create_version(
            item_type: "User",
            item_id: 1,
            object_changes: { "description" => %w[Old New] }.to_yaml,
            created_at: 30.minutes.ago
          )
        end

        it "renders successfully" do
          get "/admins/descriptions/inks"
          expect(response).to be_successful
        end

        it "includes MacroCluster versions with description changes" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.map(&:id)).to include(description_version.id)
        end

        it "includes MacroCluster versions with manual_brand_name changes" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.map(&:id)).to include(brand_name_version.id)
        end

        it "includes MacroCluster versions with manual_line_name changes" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.map(&:id)).to include(line_name_version.id)
        end

        it "includes MacroCluster versions with manual_ink_name changes" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.map(&:id)).to include(ink_name_version.id)
        end

        it "excludes versions with no tracked field changes" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.map(&:id)).not_to include(non_tracked_version.id)
        end

        it "excludes non-MacroCluster versions" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.map(&:id)).not_to include(non_macro_cluster_version.id)
        end

        it "orders versions by id desc" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.map(&:id)).to eq(
            [ink_name_version, line_name_version, brand_name_version, description_version].map(&:id)
          )
        end

        it "paginates with 100 per page" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.size).to eq(4)
          expect(versions.current_page).to eq(1)
        end

        context "with pagination" do
          before do
            # Create enough versions to test pagination
            101.times do |i|
              create_version(
                item_type: "MacroCluster",
                item_id: macro_cluster.id,
                object_changes: { "description" => ["ink desc #{i}", "new ink desc #{i}"] }.to_yaml,
                created_at: (i + 3).days.ago
              )
            end
          end

          it "returns second page when requested" do
            get "/admins/descriptions/inks", params: { page: 2 }
            versions = assigns(:versions)
            expect(versions.current_page).to eq(2)
            expect(versions.size).to be > 0
          end
        end
      end
    end
  end

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

  private

  def create_version(attributes)
    PaperTrail::Version.create!({ event: "update", whodunnit: admin.id.to_s }.merge(attributes))
  end
end
