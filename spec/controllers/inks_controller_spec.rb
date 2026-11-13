require "rails_helper"
require "active_record/testing/query_assertions"

describe InksController do
  include ActiveRecord::Assertions::QueryAssertions

  render_views

  let(:brand) { create(:brand_cluster) }
  let(:ink) { create(:macro_cluster, brand_cluster: brand) }
  let(:user) { create(:user) }

  describe "#index" do
    it "rejects a non-string tag parameter" do
      get :index, params: { tag: ["blue"] }
      expect(response).to have_http_status(:bad_request)
    end

    it "renders inks for a tag" do
      get :index, params: { tag: "blue" }
      expect(response).to be_successful
    end
  end

  describe "#show" do
    let(:page) { Nokogiri.HTML(response.body) }

    def love_elements
      page.css(".fpc-ink-review__love")
    end

    it "redirects to the brand scoped path" do
      get :show, params: { id: ink.id }
      expect(response).to redirect_to(brand_ink_path(brand, ink))
    end

    it "orders the reviews by loves" do
      create(
        :ink_review,
        macro_cluster: ink,
        approved_at: Time.current,
        title: "Few",
        loves_count: 1
      )
      create(
        :ink_review,
        macro_cluster: ink,
        approved_at: Time.current,
        title: "Most",
        loves_count: 7
      )
      create(
        :ink_review,
        macro_cluster: ink,
        approved_at: Time.current,
        title: "Some",
        loves_count: 3
      )

      get :show, params: { id: ink.id, brand_id: brand.id }

      titles = page.css(".fpc-ink-review__content > div:first-child > a:first-child").map(&:text)
      expect(titles).to eq(%w[Most Some Few])
    end

    it "fills the two columns row by row" do
      4.times do |i|
        create(
          :ink_review,
          macro_cluster: ink,
          approved_at: Time.current,
          title: "R#{i}",
          loves_count: i
        )
      end

      get :show, params: { id: ink.id, brand_id: brand.id }

      rows =
        page
          .css(".fpc-ink-details__reviews > .row")
          .map do |row|
            row.css(".fpc-ink-review__content > div:first-child > a:first-child").map(&:text)
          end
      expect(rows).to eq([%w[R3 R2], %w[R1 R0]])
    end

    it "asks signed out users to sign in to report errors" do
      create(:ink_review, macro_cluster: ink, approved_at: Time.current)

      get :show, params: { id: ink.id, brand_id: brand.id }

      expect(page.css(".fpc-report-button")).to be_empty
      expect(page.at_css(".fpc-ink-details__error-reporting a[href='/users/sign_in']").text).to eq(
        "Sign in to report an error"
      )
    end

    it "shows the love count without a button when signed out" do
      create(:ink_review, macro_cluster: ink, approved_at: Time.current, loves_count: 4)

      get :show, params: { id: ink.id, brand_id: brand.id }

      expect(love_elements.first.at_css(".fpc-ink-review__love-count").text).to eq("4 loves")
      expect(page.css(".fpc-love-button")).to be_empty
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "marks the reviews the user loved" do
        loved = create(:ink_review, macro_cluster: ink, approved_at: Time.current)
        create(:ink_review_love, ink_review: loved, user: user)
        create(:ink_review_love, ink_review: loved)
        not_loved = create(:ink_review, macro_cluster: ink, approved_at: Time.current)
        create(:ink_review_love, ink_review: not_loved)

        get :show, params: { id: ink.id, brand_id: brand.id }

        buttons =
          page
            .css(".fpc-love-button")
            .to_h do |el|
              [
                el["data-url"],
                el.attributes.slice("data-loved", "data-count").transform_values(&:value)
              ]
            end
        expect(buttons).to eq(
          "/ink_reviews/#{loved.id}/love" => {
            "data-loved" => "true",
            "data-count" => "2"
          },
          "/ink_reviews/#{not_loved.id}/love" => {
            "data-loved" => "false",
            "data-count" => "1"
          }
        )
      end

      it "offers a report button for the ink and for each review" do
        review = create(:ink_review, macro_cluster: ink, approved_at: Time.current)

        get :show, params: { id: ink.id, brand_id: brand.id }

        buttons =
          page
            .css(".fpc-report-button")
            .map do |el|
              el.attributes.slice("data-url", "data-label", "data-icon").transform_values(&:value)
            end
        expect(buttons).to contain_exactly(
          { "data-url" => ink_report_path(ink), "data-label" => "Report an error" },
          {
            "data-url" => "/ink_reviews/#{review.id}/report",
            "data-label" => "Report this review",
            "data-icon" => "true"
          }
        )
      end

      it "looks up the user's loves in one query" do
        reviews = create_list(:ink_review, 3, macro_cluster: ink, approved_at: Time.current)
        reviews.each { |review| create(:ink_review_love, ink_review: review, user: user) }

        assert_queries_match(/FROM "ink_review_loves"/, count: 1) do
          get :show, params: { id: ink.id, brand_id: brand.id }
        end
      end
    end
  end

  describe "#edit" do
    it "requires authentication" do
      get :edit, params: { id: ink.id, brand_id: brand.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "renders successfully" do
        get :edit, params: { id: ink.id, brand_id: brand.id }
        expect(response).to be_successful
      end
    end
  end

  describe "#edit_name" do
    it "requires authentication" do
      get :edit_name, params: { id: ink.id, brand_id: brand.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "renders successfully" do
        get :edit_name, params: { id: ink.id, brand_id: brand.id }
        expect(response).to be_successful
      end
    end
  end

  describe "#edit_colors" do
    it "requires authentication" do
      get :edit_colors, params: { id: ink.id, brand_id: brand.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "renders successfully" do
        get :edit_colors, params: { id: ink.id, brand_id: brand.id }
        expect(response).to be_successful
      end
    end
  end

  describe "#update" do
    it "requires authentication" do
      put :update, params: { id: ink.id, brand_id: brand.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(user) }

      it "updates successfully" do
        put :update,
            params: {
              id: ink.id,
              brand_id: brand.id,
              macro_cluster: {
                description: "description"
              }
            }
        expect(response).to redirect_to(ink_path(ink))
      end

      it "successfully sets the description" do
        expect do
          put :update,
              params: {
                id: ink.id,
                brand_id: brand.id,
                macro_cluster: {
                  description: "description"
                }
              }
        end.to change { ink.reload.description }.to("description")
      end

      it "sets the user who made the last change" do
        expect do
          put :update,
              params: {
                id: ink.id,
                brand_id: brand.id,
                macro_cluster: {
                  description: "description"
                }
              }
        end.to change { ink.reload.versions.last.whodunnit }.to(user.id.to_s)
      end

      it "successfully sets manual_brand_name" do
        expect do
          put :update,
              params: {
                id: ink.id,
                brand_id: brand.id,
                macro_cluster: {
                  manual_brand_name: "Custom Brand"
                }
              }
        end.to change { ink.reload.manual_brand_name }.to("Custom Brand")
      end

      it "successfully sets manual_line_name" do
        expect do
          put :update,
              params: {
                id: ink.id,
                brand_id: brand.id,
                macro_cluster: {
                  manual_line_name: "Custom Line"
                }
              }
        end.to change { ink.reload.manual_line_name }.to("Custom Line")
      end

      it "successfully sets manual_ink_name" do
        expect do
          put :update,
              params: {
                id: ink.id,
                brand_id: brand.id,
                macro_cluster: {
                  manual_ink_name: "Custom Ink"
                }
              }
        end.to change { ink.reload.manual_ink_name }.to("Custom Ink")
      end

      it "successfully sets ignored_colors" do
        expect do
          put :update,
              params: {
                id: ink.id,
                brand_id: brand.id,
                macro_cluster: {
                  ignored_colors: %w[#FF0000 #00FF00]
                }
              }
        end.to change { ink.reload.ignored_colors }.to(%w[#FF0000 #00FF00])
      end

      it "updates the ink embedding with the new name" do
        ink.create_ink_embedding(content: "old name")
        put :update,
            params: {
              id: ink.id,
              brand_id: brand.id,
              macro_cluster: {
                manual_brand_name: "New Brand"
              }
            }
        expect(ink.ink_embedding.reload.content).to eq(ink.reload.name)
      end
    end
  end
end
