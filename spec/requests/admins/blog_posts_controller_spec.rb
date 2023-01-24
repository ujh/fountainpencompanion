require "rails_helper"

describe Admins::BlogPostsController do
  let(:admin) { create(:admin) }

  describe "#index" do
    it "requires authentication" do
      get "/admins/blog_posts"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders successfully" do
        get "/admins/blog_posts"
        expect(response).to be_successful
      end
    end
  end

  describe "#new" do
    it "requires authentication" do
      get "/admins/blog_posts/new"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders successfully" do
        get "/admins/blog_posts/new"
        expect(response).to be_successful
      end
    end
  end

  describe "#create" do
    it "requires authentication" do
      post "/admins/blog_posts"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "creates the blog post" do
        expect do
          post "/admins/blog_posts",
               params: {
                 blog_post: {
                   title: "title",
                   body: "body"
                 }
               }
          expect(response).to redirect_to(admins_blog_posts_path)
        end.to change { BlogPost.count }.by(1)
        blog_post = BlogPost.last
        expect(blog_post.title).to eq("title")
        expect(blog_post.body).to eq("body")
      end

      it "does not create the blog post when validation fails" do
        expect do
          post "/admins/blog_posts",
               params: {
                 blog_post: {
                   title: "title",
                   body: ""
                 }
               }
          expect(response).to be_successful
        end.to_not change { BlogPost.count }
      end
    end
  end

  describe "#edit" do
    let(:blog_post) { create(:blog_post) }

    it "requires authentication" do
      get "/admins/blog_posts/#{blog_post.id}/edit"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "renders successfully" do
        get "/admins/blog_posts/#{blog_post.id}/edit"
        expect(response).to be_successful
      end
    end
  end

  describe "#update" do
    let(:blog_post) { create(:blog_post, title: "old title") }

    it "requires authentication" do
      put "/admins/blog_posts/#{blog_post.id}"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "updates the blog post" do
        expect do
          put "/admins/blog_posts/#{blog_post.id}",
              params: {
                blog_post: {
                  title: "new title"
                }
              }
          expect(response).to redirect_to(admins_blog_posts_path)
        end.to change { blog_post.reload.title }.from("old title").to(
          "new title"
        )
      end

      it "does not update the blog post when validation fails" do
        expect do
          put "/admins/blog_posts/#{blog_post.id}",
              params: {
                blog_post: {
                  title: ""
                }
              }
          expect(response).to be_successful
        end.to_not change { blog_post.reload.title }
      end
    end
  end

  describe "#destroy" do
    let!(:blog_post) { create(:blog_post) }

    it "requires authentication" do
      delete "/admins/blog_posts/#{blog_post.id}"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "deletes the blog post" do
        expect do
          delete "/admins/blog_posts/#{blog_post.id}"
          expect(response).to redirect_to(admins_blog_posts_path)
        end.to change { BlogPost.count }.by(-1)
      end
    end
  end

  describe "#publish" do
    let(:blog_post) { create(:blog_post) }

    it "requires authentication" do
      put "/admins/blog_posts/#{blog_post.id}/publish"
      expect(response).to redirect_to(new_admin_session_path)
    end

    context "signed in" do
      before(:each) { sign_in(admin) }

      it "sets the published timestamp" do
        expect(blog_post.published_at).to be_blank
        put "/admins/blog_posts/#{blog_post.id}/publish"
        expect(response).to redirect_to(admins_blog_posts_path)
        expect(blog_post.reload.published_at).to_not be_blank
      end

      it "enqueues the after publishing job" do
        expect do
          put "/admins/blog_posts/#{blog_post.id}/publish"
        end.to change { AfterBlogPostPublished.jobs.size }.by(1)
      end
    end
  end
end
