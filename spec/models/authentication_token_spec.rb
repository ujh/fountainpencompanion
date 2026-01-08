require "rails_helper"

describe AuthenticationToken do
  describe "validations" do
    it "requires a name" do
      token = build(:authentication_token, name: nil)
      expect(token).not_to be_valid
      expect(token.errors[:name]).to include("can't be blank")
    end

    it "requires a name of 100 characters or less" do
      token = build(:authentication_token, name: "a" * 101)
      expect(token).not_to be_valid
      expect(token.errors[:name]).to include("is too long (maximum is 100 characters)")
    end

    it "is valid with a name" do
      token = build(:authentication_token, name: "My Token")
      expect(token).to be_valid
    end
  end

  describe "token generation" do
    it "generates a token on initialization" do
      token = AuthenticationToken.new(name: "Test", user: create(:user))
      expect(token.token).to be_present
      expect(token.token.length).to eq(36)
    end

    it "does not regenerate the token if token_digest already exists" do
      token = create(:authentication_token)
      original_digest = token.token_digest
      reloaded_token = AuthenticationToken.find(token.id)
      expect(reloaded_token.token_digest).to eq(original_digest)
      # Plain token is not available after loading from database
      expect(reloaded_token.access_token).to be_nil
    end
  end

  describe "#access_token" do
    it "returns nil if the token is not persisted" do
      token = build(:authentication_token)
      expect(token.access_token).to be_nil
    end

    it "returns nil after reloading (when plain token is no longer available)" do
      token = create(:authentication_token)
      reloaded_token = AuthenticationToken.find(token.id)
      expect(reloaded_token.access_token).to be_nil
    end

    it "returns the access token in the correct format after creation" do
      token = create(:authentication_token)
      expect(token.access_token).to eq("#{token.id}.#{token.token}")
    end
  end

  describe ".authenticate_by" do
    it "returns the token when credentials are valid" do
      token = create(:authentication_token)
      plain_token = token.token

      found = AuthenticationToken.authenticate_by(id: token.id, token: plain_token)
      expect(found).to eq(token)
    end

    it "returns nil when token is invalid" do
      token = create(:authentication_token)

      found = AuthenticationToken.authenticate_by(id: token.id, token: "wrong_token")
      expect(found).to be_nil
    end

    it "returns nil when id does not exist" do
      found = AuthenticationToken.authenticate_by(id: 999_999, token: "any_token")
      expect(found).to be_nil
    end
  end

  describe "#touch_last_used!" do
    it "updates the last_used_at timestamp" do
      token = create(:authentication_token)
      expect(token.last_used_at).to be_nil

      token.touch_last_used!
      token.reload

      expect(token.last_used_at).to be_present
      expect(token.last_used_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe "associations" do
    it "belongs to a user" do
      token = create(:authentication_token)
      expect(token.user).to be_a(User)
    end

    it "is destroyed when the user is destroyed" do
      user = create(:user)
      token = create(:authentication_token, user: user)

      expect { user.destroy }.to change { AuthenticationToken.count }.by(-1)
    end
  end
end
