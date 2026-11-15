require "rails_helper"
require Rails.root.join(".claude/skills/review-ignored-inks/scripts/lib/common").to_s

RSpec.describe IgnoredInksReview do
  include InkReviewRoleHelpers

  describe ".database_url" do
    attr_accessor :state_dir

    around do |example|
      Dir.mktmpdir do |dir|
        self.state_dir = dir
        previous = ENV.values_at("FPC_INK_REVIEW_DATABASE_URL", "FPC_READONLY_DATABASE_URL")
        ENV.delete("FPC_INK_REVIEW_DATABASE_URL")
        ENV.delete("FPC_READONLY_DATABASE_URL")
        example.run
      ensure
        ENV["FPC_INK_REVIEW_DATABASE_URL"], ENV["FPC_READONLY_DATABASE_URL"] = previous
      end
    end

    before do
      stub_const("IgnoredInksReview::DATABASE_URL_FILE", File.join(state_dir, "database_url"))
    end

    it "reads FPC_INK_REVIEW_DATABASE_URL" do
      ENV["FPC_INK_REVIEW_DATABASE_URL"] = "postgresql://fpc_ink_review@db/defaultdb"
      File.write(IgnoredInksReview::DATABASE_URL_FILE, "postgresql://other@db/defaultdb\n")

      expect(described_class.database_url).to eq("postgresql://fpc_ink_review@db/defaultdb")
    end

    it "falls back to the state file" do
      File.write(IgnoredInksReview::DATABASE_URL_FILE, "postgresql://fpc_ink_review@db/defaultdb\n")

      expect(described_class.database_url).to eq("postgresql://fpc_ink_review@db/defaultdb")
    end

    it "ignores FPC_READONLY_DATABASE_URL" do
      ENV["FPC_READONLY_DATABASE_URL"] = "postgresql://fpc_readonly@db/defaultdb"

      expect { described_class.database_url }.to raise_error(SystemExit).and output(
              /FPC_INK_REVIEW_DATABASE_URL/
            ).to_stderr
    end
  end

  describe ".connection" do
    it "connects as a role with the documented grants, read-only" do
      with_ink_review_url(create_ink_review_role) do
        connection = described_class.connection

        expect(connection.exec("show transaction_read_only").getvalue(0, 0)).to eq("on")
        expect(connection.exec("show statement_timeout").getvalue(0, 0)).to eq("2min")
      end
    end

    it "refuses a role that can read users" do
      url = create_ink_review_role("GRANT SELECT (id) ON users TO %{role}")

      with_ink_review_url(url) do
        expect { described_class.connection }.to raise_error(SystemExit).and output(
                /can read users.*fpc_ink_review role/
              ).to_stderr
      end
    end

    it "refuses a role that can write to the review's tables" do
      url = create_ink_review_role("GRANT UPDATE ON agent_logs TO %{role}")

      with_ink_review_url(url) do
        expect { described_class.connection }.to raise_error(SystemExit).and output(
                /can write to agent_logs/
              ).to_stderr
      end
    end

    it "closes the connection it refuses" do
      connection = PG.connect(**test_database_params)
      allow(PG).to receive(:connect).and_return(connection)

      with_ink_review_url("unused") do
        expect { described_class.connection }.to raise_error(SystemExit).and output.to_stderr
      end
      expect(connection).to be_finished
    end
  end

  describe ".embedding_query" do
    it "widens the HNSW search for the query only" do
      with_ink_review_url(create_ink_review_role) do
        rows =
          described_class.embedding_query("select current_setting('hnsw.ef_search') as value", [])

        expect(rows).to eq([{ "value" => "200" }])
        expect(
          described_class
            .connection
            .exec("select current_setting('hnsw.ef_search', true)")
            .getvalue(0, 0)
        ).not_to eq("200")
      end
    end
  end
end
