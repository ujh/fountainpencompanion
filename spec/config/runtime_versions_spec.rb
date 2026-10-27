require "rails_helper"

RSpec.describe "Runtime versions" do
  def read(path) = Rails.root.join(path).read

  describe "Ruby" do
    let(:version) { read(".ruby-version").strip }

    it "matches the Dockerfile base image" do
      expect(read("Dockerfile")[%r{^FROM docker\.io/library/ruby:([\d.]+)-}, 1]).to eq(version)
    end

    it "matches the RUBY VERSION in Gemfile.lock" do
      expect(read("Gemfile.lock")[/^RUBY VERSION\n\s+ruby ([\d.]+)$/, 1]).to eq(version)
    end
  end

  describe "Node" do
    let(:version) { read(".nvmrc").strip.delete_prefix("v") }

    it "matches the Dockerfile node image" do
      expect(read("Dockerfile")[%r{^FROM docker\.io/library/node:([\d.]+)-}, 1]).to eq(version)
    end

    it "matches the engines field in package.json" do
      expect(JSON.parse(read("package.json")).dig("engines", "node").delete_prefix("v")).to eq(
        version
      )
    end
  end
end
