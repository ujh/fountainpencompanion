# Database role `fpc_ink_review`

The skill's scripts connect to production as `fpc_ink_review`, a role that can read only what the
review needs. Subagents read user-typed names and agent logs, have web access and can run any
`SELECT` through `scripts/query.rb`, so the role, not the prompts, decides what they can reach.
`scripts/lib/common.rb` refuses to run as a role that can write to any table or view in `public`, read
`users` (such as `fpc_readonly`), is a member of any role (such as `pg_read_all_stats`) or has
`SUPERUSER`, `CREATEDB`, `CREATEROLE`, `BYPASSRLS` or `REPLICATION`.

## What the scripts read

| Table            | Granted                                                                                       | Used for                                                                                                                |
| ---------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `macro_clusters` | all columns                                                                                   | names (with `manual_*`, `line_name_is_empty`), colour, description, created date (`common.rb`, `export.rb`, `check.rb`) |
| `micro_clusters` | all columns                                                                                   | simplified names, `ignored`, `macro_cluster_id`, dates (`export.rb` selects `mc.*`, `lookup.rb`)                        |
| `ink_embeddings` | all columns                                                                                   | `owner_type`, `owner_id`, `embedding` for `lookup.rb neighbours`                                                        |
| `collected_inks` | `user_id`, `micro_cluster_id`, `brand_name`, `line_name`, `ink_name`, `color`                 | names and colours of the inks in a cluster; `user_id` only for distinct-user counts                                     |
| `agent_logs`     | `id`, `name`, `owner_type`, `owner_id`, `state`, `agent_approved`, `extra_data`, `created_at` | `InkClusterer` and `IgnoredInkReview` logs of micro clusters (`export.rb`)                                              |

Nothing else: no `users`, `authentication_tokens`, `collected_pens`, `currently_inked`,
`patreon_credentials` or any other table, none of the comments, `private`, `maker` or `kind` of
`collected_inks`, and no `transcript` or `usage` of `agent_logs`. The extension functions the
scripts call (`similarity`, `<=>`) are executable by everyone.

What the role can still read that is personal:

- `collected_inks.user_id` with the names of every ink, private ones included. User ids also
  appear in public profile URLs, so the inks of a user with a public profile can be tied to their
  name.
- `agent_logs.extra_data` of every agent, not only the clusterer's, for example the messages users
  send to the pen and ink suggester and the spam classifier's explanations about accounts (owner
  `User`).
- `ink_embeddings` rows of collected inks: `content` (the ink's short name), `owner_id` (the
  collected ink's id) and timestamps. The role cannot read `collected_inks.id`, so these rows cannot
  be joined to a `user_id`.

Column grants cannot filter rows, so removing these needs views or row-level security.

## Setup (owner, as `doadmin`)

```sh
doctl databases list                                    # cluster id
doctl databases user create <cluster-id> fpc_ink_review
```

Then run [`database-role.sql`](database-role.sql) as `doadmin` against `defaultdb`. It grants the
table and column privileges above, removes `CREATEDB`, `CREATEROLE` and `REPLICATION` in case the
new user has them, and sets three role defaults:

- `default_transaction_read_only = on` and `statement_timeout = '120s'`: role defaults apply to
  every connection of the role, also when a statement reaches the server through a pooler. The
  scripts set the same two for their session as a second layer.
- `CONNECTION LIMIT 6`: the role connects directly (port 25060), like `fpc_readonly`, outside the
  pools, which take all 97 connections (see `docs/database-roles.md`). Each script holds one
  connection while it runs; subagents run one at a time, but a subagent often runs several scripts
  in parallel.

Tables that later migrations create get no grant. When a script or prompt needs another table or
column, add it to `database-role.sql` and run the new `GRANT`; `spec/skills/review_ignored_inks/`
runs the scripts as a role with exactly the grants in that file.

## Connection URL

Same host as the cluster's direct connection, port 25060, database `defaultdb`, `sslmode=require`,
user `fpc_ink_review`. Read the password into a file, never the terminal:

```sh
(umask 077 && doctl databases user get <cluster-id> fpc_ink_review --show > tmp/.ink_review_user)
```

Write `postgresql://fpc_ink_review:<password>@<host>:25060/defaultdb?sslmode=require` to
`tmp/ignored-inks-review/database_url` with mode 600 (replacing the URL there), or set it as
`FPC_INK_REVIEW_DATABASE_URL`, then `rm tmp/.ink_review_user`.

## Verification (as `doadmin`)

Attributes and defaults (expect `f, f, f, f, f, 6, {default_transaction_read_only=on,statement_timeout=120s}`):

```sql
SELECT rolsuper, rolcreaterole, rolcreatedb, rolbypassrls, rolreplication, rolconnlimit, rolconfig
FROM pg_roles WHERE rolname = 'fpc_ink_review';
```

Role memberships (expect no rows; `pg_read_all_data` would read every table, `pg_read_all_stats`
would show other sessions' statements with their literal values):

```sql
SELECT roleid::regrole FROM pg_auth_members WHERE member = 'fpc_ink_review'::regrole;
```

Readable tables and views (expect `agent_logs`, `collected_inks`, `ink_embeddings`,
`macro_clusters`, `micro_clusters`, plus `pg_stat_statements` and `pg_stat_statements_info`, which
the extension grants to everyone; without `pg_read_all_stats` they hide other roles' query text):

```sql
SELECT c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p', 'v', 'm')
  AND has_any_column_privilege('fpc_ink_review', c.oid, 'SELECT')
ORDER BY 1;
```

Sensitive tables (expect `f` for each):

```sql
SELECT t, has_any_column_privilege('fpc_ink_review', t, 'SELECT')
FROM unnest(ARRAY['users', 'authentication_tokens', 'collected_pens', 'currently_inked',
                  'patreon_credentials', 'usage_records']) t;
```

Readable columns of the two partly granted tables (expect the columns in the table above):

```sql
SELECT a.attrelid::regclass, a.attname
FROM pg_attribute a
WHERE a.attrelid IN ('collected_inks'::regclass, 'agent_logs'::regclass)
  AND a.attnum > 0 AND NOT a.attisdropped
  AND has_column_privilege('fpc_ink_review', a.attrelid, a.attnum, 'SELECT')
ORDER BY 1, 2;
```

No write privilege anywhere, column grants included (expect no rows; the privilege functions are
true if any privilege of a list is held, so this checks one at a time). The scripts run the same
check:

```sql
SELECT c.relname, p.privilege
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN (VALUES ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) AS p(privilege)
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
  AND CASE WHEN p.privilege IN ('INSERT', 'UPDATE')
           THEN has_any_column_privilege('fpc_ink_review', c.oid, p.privilege)
           ELSE has_table_privilege('fpc_ink_review', c.oid, p.privilege) END;
```

Then through the skill, from the repository root (expect `fpc_ink_review`, `on`, `2min`, then
`permission denied for table users`):

```sh
echo "select current_user, current_setting('default_transaction_read_only'), current_setting('statement_timeout')" |
  ruby .claude/skills/review-ignored-inks/scripts/query.rb
echo "select count(*) from users" | ruby .claude/skills/review-ignored-inks/scripts/query.rb
```
