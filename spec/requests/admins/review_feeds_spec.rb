require "rails_helper"
require "active_record/testing/query_assertions"

describe "Admins::ReviewFeeds" do
  include ActiveRecord::Assertions::QueryAssertions

  let(:admin) { create(:user, :admin) }
  let!(:feed) do
    create(:review_feed, host: "inkblog.example.com", feed_url: "https://inkblog.example.com/feed")
  end

  describe "access" do
    it "is limited to admins" do
      sign_in(create(:user))

      get "/admins/review_feeds"
      expect(response).to redirect_to(new_user_session_path)

      get "/admins/review_feeds/new"
      expect(response).to redirect_to(new_user_session_path)

      get "/admins/review_feeds/#{feed.id}/edit"
      expect(response).to redirect_to(new_user_session_path)

      post "/admins/review_feeds",
           params: {
             review_feed: {
               host: "new.example.com",
               feed_url: "https://new.example.com/feed"
             }
           }
      expect(ReviewFeed.count).to eq(1)

      patch "/admins/review_feeds/#{feed.id}",
            params: {
              review_feed: {
                feed_url: "https://inkblog.example.com/atom.xml"
              }
            }
      patch "/admins/review_feeds/#{feed.id}/ignore"
      expect(feed.reload).to have_attributes(
        state: "active",
        feed_url: "https://inkblog.example.com/feed"
      )

      feed.update!(state: "ignored")
      patch "/admins/review_feeds/#{feed.id}/enable"
      expect(feed.reload.state).to eq("ignored")
    end

    it "requires a signed in user" do
      get "/admins/review_feeds"

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "as an admin" do
    before { sign_in(admin) }

    describe "GET /admins/review_feeds" do
      it "lists the feeds with their page counts and approved reviews" do
        feed.update!(
          failure_count: 3,
          first_failed_at: Time.zone.local(2026, 11, 10, 8, 0),
          last_error: "Faraday::TimeoutError: execution expired"
        )
        create_list(:web_page_for_review, 2, review_feed: feed, state: "processed")
        create(:web_page_for_review, review_feed: feed, state: "filtered")
        create(:ink_review, url: "https://www.inkblog.example.com/a", approved_at: Time.current)
        create(:ink_review, url: "https://inkblog.example.com/b", approved_at: Time.current)
        create(:ink_review, url: "https://inkblog.example.com/c")

        get "/admins/review_feeds"

        expect(response).to be_successful
        row = Nokogiri.HTML(response.body).at_css("#review_feed_#{feed.id}")
        cells = row.css("td").map { |td| td.text.squish }
        expect(cells[0..3]).to eq(
          %w[inkblog.example.com active no https://inkblog.example.com/feed]
        )
        expect(cells[6]).to include("3", "since")
        expect(cells[7]).to eq("Faraday::TimeoutError: execution expired")
        expect(cells[8..12]).to eq(%w[0 2 0 1 2])
        expect(row.at_css("a[href='https://inkblog.example.com/feed']")).to be_present
      end

      it "filters by state" do
        create(:review_feed, :ignored, host: "shop.example.com")

        get "/admins/review_feeds", params: { state: "ignored" }

        expect(response.body).to include("shop.example.com")
        expect(response.body).not_to include("inkblog.example.com")
      end

      it "lists every feed for an unknown state" do
        create(:review_feed, :ignored, host: "shop.example.com")

        get "/admins/review_feeds", params: { state: "bogus" }

        expect(response.body).to include("shop.example.com", "inkblog.example.com")
      end

      it "loads the counts with one query each, whatever the number of feeds" do
        3.times do |i|
          other = create(:review_feed, host: "blog#{i}.example.com")
          create(:web_page_for_review, review_feed: other, state: "pending")
          create(:ink_review, url: "https://blog#{i}.example.com/review", approved_at: Time.current)
        end

        assert_queries_match(/FROM "review_feeds"/, count: 1) do
          assert_queries_match(/FROM "web_page_for_reviews"/, count: 1) do
            assert_queries_match(/FROM "ink_reviews"/, count: 1) { get "/admins/review_feeds" }
          end
        end
        expect(response).to be_successful
      end

      describe "state buttons" do
        def state_forms(feed)
          get "/admins/review_feeds", params: { state: feed.state }
          row = Nokogiri.HTML(response.body).at_css("#review_feed_#{feed.id}")
          row.css("form").to_h { |form| [form["action"], form] }
        end

        def expect_patch_form(form, state)
          expect(form["method"]).to eq("post")
          expect(form.at_css("input[name='_method']")["value"]).to eq("patch")
          expect(form.at_css("input[name='filter_state']")["value"]).to eq(state)
        end

        it "offers only Ignore for an active feed" do
          forms = state_forms(feed)

          expect(forms.keys).to eq(["/admins/review_feeds/#{feed.id}/ignore"])
          expect_patch_form(forms.values.first, "active")
          expect(forms.values.first.text).to include("Ignore")
        end

        it "offers only Re-enable for an ignored feed" do
          feed.update!(state: "ignored")

          forms = state_forms(feed)

          expect(forms.keys).to eq(["/admins/review_feeds/#{feed.id}/enable"])
          expect_patch_form(forms.values.first, "ignored")
        end

        it "offers both for a failing feed" do
          feed.update!(state: "failing")

          forms = state_forms(feed)

          expect(forms.keys).to eq(
            %W[/admins/review_feeds/#{feed.id}/ignore /admins/review_feeds/#{feed.id}/enable]
          )
          forms.each_value { |form| expect_patch_form(form, "failing") }
        end
      end

      it "links to the feeds page from the admin nav" do
        get "/admins/review_feeds"

        expect(response.body).to include(%(href="/admins/review_feeds">Feeds</a>))
      end
    end

    describe "GET /admins/review_feeds/new" do
      it "renders the form" do
        get "/admins/review_feeds/new"

        expect(response).to be_successful
        expect(response.body).to include("review_feed[host]", "review_feed[feed_url]")
      end
    end

    describe "POST /admins/review_feeds" do
      it "creates an active hand-picked feed that skips its back catalog" do
        post "/admins/review_feeds",
             params: {
               review_feed: {
                 host: "WWW.Example.com",
                 feed_url: "https://feeds.feedburner.com/example"
               }
             }

        expect(response).to redirect_to(admins_review_feeds_path)
        expect(ReviewFeed.find_by(host: "example.com")).to have_attributes(
          feed_url: "https://feeds.feedburner.com/example",
          state: "active",
          curated: true,
          back_catalog_imported: false
        )
      end

      it "ignores attempts to set other attributes" do
        post "/admins/review_feeds",
             params: {
               review_feed: {
                 host: "example.com",
                 feed_url: "https://example.com/feed",
                 state: "ignored",
                 curated: "0",
                 back_catalog_imported: "1"
               }
             }

        expect(ReviewFeed.find_by(host: "example.com")).to have_attributes(
          state: "active",
          curated: true,
          back_catalog_imported: false
        )
      end

      it "re-renders the form with errors" do
        post "/admins/review_feeds",
             params: {
               review_feed: {
                 host: "inkblog.example.com",
                 feed_url: ""
               }
             }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("has already been taken", "can&#39;t be blank")
        expect(ReviewFeed.count).to eq(1)
      end
    end

    describe "GET /admins/review_feeds/:id/edit" do
      it "renders the form with the curated checkbox" do
        get "/admins/review_feeds/#{feed.id}/edit"

        expect(response).to be_successful
        expect(response.body).to include(
          "https://inkblog.example.com/feed",
          "Hand-picked: fetch hourly, no pre-filter"
        )
        expect(response.body).not_to include("review_feed[host]")
      end
    end

    describe "PATCH /admins/review_feeds/:id" do
      it "updates the feed through UpdateReviewFeed" do
        feed.update!(back_catalog_imported: true)

        patch "/admins/review_feeds/#{feed.id}",
              params: {
                review_feed: {
                  feed_url: "https://inkblog.example.com/atom.xml",
                  curated: "1",
                  host: "other.example.com"
                }
              }

        expect(response).to redirect_to(admins_review_feeds_path)
        expect(feed.reload).to have_attributes(
          host: "inkblog.example.com",
          feed_url: "https://inkblog.example.com/atom.xml",
          curated: true,
          back_catalog_imported: false
        )
      end

      it "re-renders the form when the feed URL of an active feed is blanked" do
        patch "/admins/review_feeds/#{feed.id}", params: { review_feed: { feed_url: "" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("can&#39;t be blank")
        expect(feed.reload.feed_url).to eq("https://inkblog.example.com/feed")
      end

      it "shows the stored state when a new feed URL on an ignored feed is refused" do
        ignored = create(:review_feed, :ignored, host: "shop.example.com")

        patch "/admins/review_feeds/#{ignored.id}",
              params: {
                review_feed: {
                  feed_url: "shop/feed"
                }
              }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("shop.example.com (ignored)")
        expect(response.body).to include("must be an http(s) URL with a host")
        expect(ignored.reload.state).to eq("ignored")
      end
    end

    describe "PATCH /admins/review_feeds/:id/ignore" do
      it "ignores the feed" do
        patch "/admins/review_feeds/#{feed.id}/ignore"

        expect(response).to redirect_to(admins_review_feeds_path)
        expect(flash[:notice]).to eq("Feed for inkblog.example.com is now ignored")
        expect(feed.reload).to have_attributes(
          state: "ignored",
          feed_url: "https://inkblog.example.com/feed"
        )
      end

      it "returns to the filtered list" do
        patch "/admins/review_feeds/#{feed.id}/ignore", params: { filter_state: "active" }

        expect(response).to redirect_to(admins_review_feeds_path(state: "active"))
      end
    end

    describe "PATCH /admins/review_feeds/:id/enable" do
      it "re-enables the feed" do
        feed.update!(state: "ignored", back_catalog_imported: true)

        patch "/admins/review_feeds/#{feed.id}/enable"

        expect(response).to redirect_to(admins_review_feeds_path)
        expect(flash[:notice]).to eq("Feed for inkblog.example.com is now active")
        expect(feed.reload).to have_attributes(state: "active", back_catalog_imported: false)
      end

      it "queues a feed without a URL for discovery" do
        ignored = create(:review_feed, :ignored, discovered_at: 1.day.ago)

        patch "/admins/review_feeds/#{ignored.id}/enable"

        expect(ignored.reload).to have_attributes(state: "no_feed", discovered_at: nil)
      end
    end
  end
end
