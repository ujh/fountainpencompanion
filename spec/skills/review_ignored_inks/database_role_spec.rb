require "rails_helper"
require Rails.root.join(".claude/skills/review-ignored-inks/scripts/lib/common").to_s

RSpec.describe "review-ignored-inks database role" do
  include InkReviewRoleHelpers

  def readable_relations(role)
    admin_connection.exec_params(<<~SQL, [role]).column_values(0)
        select c.relname
        from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
          and c.relname not like 'pg_stat_statements%'
          and has_any_column_privilege($1, c.oid, 'SELECT')
        order by 1
      SQL
  end

  def readable_columns(role, table)
    admin_connection.exec_params(<<~SQL, [role, table]).column_values(0)
        select a.attname
        from pg_attribute a
        where a.attrelid = $2::regclass and a.attnum > 0 and not a.attisdropped
          and has_column_privilege($1, a.attrelid, a.attnum, 'SELECT')
        order by 1
      SQL
  end

  def run_script(name, *args)
    previous = ARGV.dup
    ARGV.replace(args.map(&:to_s))
    load InkReviewRoleHelpers::SKILL_DIR.join("scripts", name).to_s, true
  ensure
    ARGV.replace(previous)
  end

  it "reads only the review's tables" do
    create_ink_review_role
    role = ink_review_roles.last

    expect(readable_relations(role)).to eq(
      %w[agent_logs collected_inks ink_embeddings macro_clusters micro_clusters]
    )
  end

  it "sets the role's defaults and removes administrative attributes" do
    create_ink_review_role
    role = ink_review_roles.last

    attributes = admin_connection.exec_params(<<~SQL, [role]).first
        select rolcreatedb, rolcreaterole, rolconnlimit, array_to_string(rolconfig, ' ') as config
        from pg_roles where rolname = $1
      SQL

    expect(attributes).to include(
      "rolcreatedb" => "f",
      "rolcreaterole" => "f",
      "rolconnlimit" => "6"
    )
    expect(attributes["config"].split).to match_array(
      %w[default_transaction_read_only=on statement_timeout=120s]
    )
  end

  it "reads no personal columns of collected inks and no agent transcripts" do
    create_ink_review_role
    role = ink_review_roles.last

    expect(readable_columns(role, "collected_inks")).to match_array(
      %w[user_id micro_cluster_id brand_name line_name ink_name color]
    )
    expect(readable_columns(role, "agent_logs")).to match_array(
      %w[id name owner_type owner_id state agent_approved extra_data created_at]
    )
  end

  it "is enough for every query of the export and lookup scripts" do
    with_ink_review_url(create_ink_review_role) do
      Dir.mktmpdir do |run_dir|
        stub_const("IgnoredInksReview::MERGE_BACKLOG", File.join(run_dir, "merge-backlog.json"))

        expect { run_script("export.rb", run_dir) }.to output(/"candidates": 0/).to_stdout
        expect { run_script("lookup.rb", "neighbours", 1) }.to output(
          /"macro_clusters": \[\]/
        ).to_stdout
        expect { run_script("lookup.rb", "search", "Yoi") }.to output(/"ink": "yoi"/).to_stdout
        expect { run_script("lookup.rb", "search", "Yoi", "--brand", "Sailor") }.to output(
          /"brand": "sailor"/
        ).to_stdout
        expect { run_script("lookup.rb", "macro", 1) }.to output(/\[\]/).to_stdout
      end
    end
  end

  it "leaves no HNSW setting on the session after a neighbour lookup" do
    with_ink_review_url(create_ink_review_role) do
      expect { run_script("lookup.rb", "neighbours", 1) }.to output.to_stdout

      expect(
        IgnoredInksReview
          .connection
          .exec("select current_setting('hnsw.ef_search', true)")
          .getvalue(0, 0)
      ).not_to eq("200")
    end
  end
end
