require "rails_helper"

describe CustomSessionsController, type: :request do
  describe "POST /users/sign_in" do
    context "magic-link branch (no password)" do
      it "shows the paranoid flash when the email matches a user" do
        user = create(:user)

        post "/users/sign_in", params: { user: { email: user.email } }

        expect(response).to have_http_status(:ok)
        expect(flash[:notice]).to eq(I18n.t("devise.passwordless.magic_link_sent_paranoid"))
        expect(flash[:alert]).to be_blank
      end

      it "shows the same paranoid flash when the email is unknown" do
        post "/users/sign_in", params: { user: { email: "nobody@example.com" } }

        expect(response).to have_http_status(:ok)
        expect(flash[:notice]).to eq(I18n.t("devise.passwordless.magic_link_sent_paranoid"))
        expect(flash[:alert]).to be_blank
      end

      it "sends a magic link only when the user exists" do
        existing = create(:user)
        magic_link_calls = 0
        original = User.instance_method(:send_magic_link)
        User.define_method(:send_magic_link) do |*args, **kwargs|
          magic_link_calls += 1
          nil
        end

        begin
          post "/users/sign_in", params: { user: { email: existing.email } }
          post "/users/sign_in", params: { user: { email: "nobody@example.com" } }
        ensure
          User.define_method(:send_magic_link, original)
        end

        expect(magic_link_calls).to eq(1)
      end

      it "does not 500 when the email param is missing" do
        post "/users/sign_in", params: { user: { password: "" } }

        expect(response).to have_http_status(:ok)
        expect(flash[:notice]).to eq(I18n.t("devise.passwordless.magic_link_sent_paranoid"))
      end

      it "does not 500 when the email param is blank" do
        post "/users/sign_in", params: { user: { email: "   " } }

        expect(response).to have_http_status(:ok)
        expect(flash[:notice]).to eq(I18n.t("devise.passwordless.magic_link_sent_paranoid"))
      end
    end
  end
end
