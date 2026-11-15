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

    {
      "UPDATE ON agent_logs" => "agent_logs",
      "UPDATE (state) ON agent_logs" => "agent_logs",
      "INSERT ON ink_embeddings" => "ink_embeddings",
      "DELETE ON micro_clusters" => "micro_clusters",
      "TRUNCATE ON collected_inks" => "collected_inks"
    }.each do |privilege, table|
      it "refuses a role with #{privilege}" do
        url = create_ink_review_role("GRANT #{privilege} TO %{role}")

        with_ink_review_url(url) do
          expect { described_class.connection }.to raise_error(SystemExit).and output(
                  /can write to #{table}\./
                ).to_stderr
        end
      end
    end

    it "refuses a role that can write to a view" do
      view = "ink_review_test_view_#{SecureRandom.hex(4)}"
      admin_connection.exec("CREATE VIEW #{view} AS SELECT id, state FROM agent_logs")
      url = create_ink_review_role("GRANT INSERT ON #{view} TO %{role}")

      with_ink_review_url(url) do
        expect { described_class.connection }.to raise_error(SystemExit).and output(
                /can write to #{view}\./
              ).to_stderr
      end
    ensure
      admin_connection.exec("DROP VIEW IF EXISTS #{view}")
    end

    %w[SUPERUSER CREATEDB CREATEROLE BYPASSRLS REPLICATION].each do |attribute|
      it "refuses a role with #{attribute}" do
        url = create_ink_review_role("ALTER ROLE %{role} #{attribute}")

        with_ink_review_url(url) do
          expect { described_class.connection }.to raise_error(SystemExit).and output(
                  /has #{attribute}\./
                ).to_stderr
        end
      end
    end

    it "names every administrative attribute the role has" do
      url = create_ink_review_role("ALTER ROLE %{role} SUPERUSER CREATEDB BYPASSRLS")

      with_ink_review_url(url) do
        expect { described_class.connection }.to raise_error(SystemExit).and output(
                /has SUPERUSER, CREATEDB, BYPASSRLS\./
              ).to_stderr
      end
    end

    %w[pg_read_all_data pg_read_all_stats pg_monitor].each do |built_in_role|
      it "refuses a member of #{built_in_role}" do
        url = create_ink_review_role("GRANT #{built_in_role} TO %{role}")

        with_ink_review_url(url) do
          expect { described_class.connection }.to raise_error(SystemExit).and output(
                  /member of #{built_in_role}/
                ).to_stderr
        end
      end
    end

    it "refuses a member of any role, even without inheriting its privileges" do
      group = "fpc_ink_review_test_group_#{SecureRandom.hex(4)}"
      admin_connection.exec("CREATE ROLE #{group} NOLOGIN")
      ink_review_roles << group
      url = create_ink_review_role("GRANT #{group} TO %{role} WITH INHERIT FALSE")

      with_ink_review_url(url) do
        expect { described_class.connection }.to raise_error(SystemExit).and output(
                /member of #{group}/
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
