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

        let!(:version_1) do
          create_version(
            item_type: "MacroCluster",
            item_id: macro_cluster.id,
            object_changes: { "description" => [nil, "First ink description"] }.to_yaml,
            created_at: 2.days.ago
          )
        end

        let!(:version_2) do
          create_version(
            item_type: "MacroCluster",
            item_id: macro_cluster.id,
            object_changes: {
              "description" => ["First ink description", "Updated ink description"]
            }.to_yaml,
            created_at: 1.day.ago
          )
        end

        let!(:non_description_version) do
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

        it "only includes MacroCluster versions with description changes" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.map(&:id)).to contain_exactly(version_2.id, version_1.id)
        end

        it "orders versions by id desc" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.map(&:id)).to eq([version_2.id, version_1.id])
        end

        it "paginates with 100 per page" do
          get "/admins/descriptions/inks"
          versions = assigns(:versions)
          expect(versions.size).to eq(2)
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
                created_at: i.hours.ago
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

  describe "#calculate_diff" do
    let(:controller) { described_class.new }

    context "with version containing description changes" do
      let(:version) do
        double(
          "version",
          changeset: {
            "description" => ["Old ink description", "New ink description"]
          }
        )
      end

      it "calculates diff between old and new descriptions" do
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        result = controller.send(:calculate_diff, version)

        expect(Differ).to have_received(:diff_by_word).with(
          "New ink description",
          "Old ink description"
        )
        expect(result).to eq("formatted diff")
      end
    end

    context "with version containing nil to string change" do
      let(:version) do
        double("version", changeset: { "description" => [nil, "New ink description"] })
      end

      it "handles nil values by converting to string" do
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        controller.send(:calculate_diff, version)

        expect(Differ).to have_received(:diff_by_word).with("New ink description", "")
      end
    end

    context "with version containing string to nil change" do
      let(:version) do
        double("version", changeset: { "description" => ["Old ink description", nil] })
      end

      it "handles nil values by converting to string" do
        allow(Differ).to receive(:diff_by_word).and_return(
          double("diff", format_as: double("formatted", html_safe: "formatted diff"))
        )

        controller.send(:calculate_diff, version)

        expect(Differ).to have_received(:diff_by_word).with("", "Old ink description")
      end
    end
  end

  private

  def create_version(attributes)
    PaperTrail::Version.create!({ event: "update", whodunnit: admin.id.to_s }.merge(attributes))
  end
end
