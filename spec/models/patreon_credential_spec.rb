require "rails_helper"

describe PatreonCredential do
  describe ".configured?" do
    it "is false when no row exists" do
      expect(described_class.configured?).to be(false)
    end

    it "is true once a credential exists" do
      described_class.create!(access_token: "a", refresh_token: "r", expires_at: 1.day.from_now)
      expect(described_class.configured?).to be(true)
    end
  end

  describe "#expired?" do
    it "is true when expires_at is nil" do
      cred = described_class.new(access_token: "a", refresh_token: "r", expires_at: nil)
      expect(cred).to be_expired
    end

    it "is true within the leeway window" do
      cred =
        described_class.new(access_token: "a", refresh_token: "r", expires_at: 1.minute.from_now)
      expect(cred).to be_expired
    end

    it "is false comfortably before expiry" do
      cred = described_class.new(access_token: "a", refresh_token: "r", expires_at: 1.hour.from_now)
      expect(cred).not_to be_expired
    end
  end

  describe ".access_token!" do
    it "returns the token when still valid" do
      described_class.create!(
        access_token: "valid",
        refresh_token: "r",
        expires_at: 1.hour.from_now
      )
      expect(described_class.access_token!).to eq("valid")
    end

    it "refreshes and persists a rotated pair when expired" do
      cred =
        described_class.create!(access_token: "old", refresh_token: "old-refresh", expires_at: nil)
      allow(PatreonClient).to receive(:refresh_token).with("old-refresh").and_return(
        access_token: "fresh",
        refresh_token: "fresh-refresh",
        expires_in: 3600
      )

      expect(described_class.access_token!).to eq("fresh")

      cred.reload
      expect(cred.access_token).to eq("fresh")
      expect(cred.refresh_token).to eq("fresh-refresh")
      expect(cred.expires_at).to be_within(5.seconds).of(3600.seconds.from_now)
    end

    it "raises when not configured" do
      expect { described_class.access_token! }.to raise_error(/No Patreon credential/)
    end
  end
end
