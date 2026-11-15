# Database roles

Production runs on a DigitalOcean PostgreSQL cluster (PG 18) behind DigitalOcean's PgBouncer
connection pools in transaction mode. Each process connects as its own database role:

| Role         | Used by                                         | Pool     | Statement timeout |
| ------------ | ----------------------------------------------- | -------- | ----------------- |
| `fpc_web`    | Puma (`web` process group), including PgHero    | `web`    | 15 s              |
| `fpc_worker` | Sidekiq (`worker` process group)                | `worker` | none              |
| `doadmin`    | `release_command` (migrations, seeds), consoles | `pool`   | none              |

`fpc_readonly` (read-only analysis, see the ignored-inks skill) is separate and not covered here.

Why:

- **Statement timeout for web requests.** rack-timeout abandons a request after 25 s, but its query
  keeps running in Postgres and holds the connection. The 15 s role default cancels any single web
  statement that runs longer, so a request whose query used to take 15–25 s now fails with
  `ActiveRecord::QueryCanceled` instead of succeeding slowly. New Relic showed no such web
  statement over 30 days (November 2026) outside a database-wide stall on 2026-11-11/12; the slowest
  page was the pen model search (`/pen_models`, `Pens::Model.embedding_search`) at 8.7 s of database
  time over three queries. Worker jobs (matview refresh, `ANALYZE`, `MacroCluster.embedding_search`
  in agents and review workers) take longer and get no timeout. The timeout
  has to be a role default: under transaction pooling a session `SET` reaches whichever server
  connection the next statement lands on. PgBouncer keeps server connections per (user, database)
  and Postgres applies role defaults when a server connection starts, so the web role's timeout
  never reaches worker or `doadmin` connections.
- **Least privilege.** The app no longer runs as the cluster admin. `fpc_web` and `fpc_worker` can
  read and write rows but cannot change the schema (verified below).
- **Migrations stay on `doadmin`.** DDL needs the table owner, and every table, matview and
  sequence in `public` is owned by `doadmin`. Session `SET`s from StrongMigrations stay on
  `doadmin`'s server connections.

## How the code picks the role

All Fly secrets reach every machine. The process decides which one it uses:

- `config/puma.rb` replaces `DATABASE_URL` with `WEB_DATABASE_URL` when that is set, before the app
  is preloaded, so all Puma workers connect as `fpc_web`. This needs Puma started with
  `bundle exec puma` (as `fly.toml` does): `bin/rails server` builds the app before it reads
  `config/puma.rb`.
- `bin/sidekiq-with-healthcheck` exports `DATABASE_URL="$WORKER_DATABASE_URL"` when that is set and
  non-empty, before starting Sidekiq.
- Everything else (release command, console, `bin/rails runner`) uses `DATABASE_URL`, which points
  at the `pool` pool as `doadmin`.

With neither secret set, every process uses `DATABASE_URL` as before. Unsetting a secret switches
that process group back.

## Privileges

What the app does at runtime (searched in `app/`, `lib/` and `config/` for `TRUNCATE`, runtime
DDL, advisory locks, `COPY`, `LOCK TABLE`, temporary tables, `REFRESH`, `ANALYZE`, `VACUUM`,
`reset_pk_sequence`):

- Row reads and writes, `SELECT … FOR UPDATE` (`lock!`, `with_lock` in `InkReview`,
  `MergeMacroClusters`, `InkClusterer`) and `INSERT … ON CONFLICT DO UPDATE` (`upsert` in
  `CspReport`, `IgnoreReviewSource`): covered by `SELECT, INSERT, UPDATE, DELETE`.
- `REFRESH MATERIALIZED VIEW [CONCURRENTLY]` on `macro_cluster_popularities` and
  `pen_name_popularities` (`MaterializedView#refresh`, called only from the
  `RefreshAutocompletePopularities` worker): needs `MAINTAIN` (PG 17+), worker only.
- Database-wide `ANALYZE` (`app/workers/analyze.rb`): needs `MAINTAIN`, worker only. Tables the
  worker lacks `MAINTAIN` on (system catalogs) are skipped with a `WARNING`; that is harmless.
- `SET LOCAL hnsw.ef_search` inside the embedding searches (`MacroCluster.embedding_search`,
  `Pens::Model.embedding_search`): a user setting, no privilege needed.
- None of `TRUNCATE`, runtime DDL, `COPY`, `LOCK TABLE`, temporary tables, `VACUUM` or
  `reset_pk_sequence!`. Advisory locks are off in production (`advisory_locks: false` in
  `config/database.yml`) and nothing takes one at runtime.

### PgHero as `fpc_web`

PgHero runs inside the web process, so it connects as `fpc_web`. Compared with `doadmin`:

- Kill / Kill all on backends of other roles fails (no `pg_signal_backend`).
- Its Analyze button skips tables (no `MAINTAIN` for `fpc_web`).
- Resetting query stats fails (no `EXECUTE` on `pg_stat_statements_reset`).
- Explain and other queries it runs are cancelled after 15 s.
- Query text of other roles' sessions and statements is hidden unless `fpc_web` gets
  `pg_read_all_stats` (optional grant below).

Use a console as `doadmin` for anything PgHero can no longer do.

## Setup SQL (owner, as `doadmin`)

Create the users first; DigitalOcean generates their passwords (`--show` reveals them):

```sh
doctl databases list                                   # cluster id
doctl databases user create <cluster-id> fpc_web
doctl databases user create <cluster-id> fpc_worker
```

Then run as `doadmin` against `defaultdb` (a direct connection or the `pool` pool), **before** any
pool for these users exists, because role defaults only apply when a server connection starts:

```sql
GRANT USAGE ON SCHEMA public TO fpc_web, fpc_worker;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO fpc_web, fpc_worker;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO fpc_web, fpc_worker;
GRANT MAINTAIN ON ALL TABLES IN SCHEMA public TO fpc_worker;

ALTER DEFAULT PRIVILEGES FOR ROLE doadmin IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO fpc_web, fpc_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE doadmin IN SCHEMA public
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO fpc_web, fpc_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE doadmin IN SCHEMA public
  GRANT MAINTAIN ON TABLES TO fpc_worker;

ALTER ROLE fpc_web SET statement_timeout = '15s';

-- Optional: lets PgHero show query text of other roles.
GRANT pg_read_all_stats TO fpc_web;
```

`ON ALL TABLES` and `ON TABLES` include views and materialized views. A "no privileges were
granted" warning for a view owned by another role (such as the `pg_stat_statements` views, if an
extension created them) is harmless; the verification below checks the app's tables. The default
privileges cover tables, matviews and sequences that future migrations create as `doadmin`;
anything created by another role needs its own grants.

Changing `statement_timeout` later reaches only new server connections; existing ones keep the old
value until PgBouncer replaces them.

## Verification

As `doadmin` (or `fpc_readonly` where noted). The privilege and owner queries should return no
rows. `has_table_privilege` and `has_sequence_privilege` are true if **any** privilege in
a comma-separated list is held, so these check one privilege at a time.

Role defaults (expect `{statement_timeout=15s}` for `fpc_web` and nothing for `fpc_worker`):

```sql
SELECT rolname, rolconfig FROM pg_roles WHERE rolname LIKE 'fpc_%';
```

Neither role may create objects in `public` (expect `f, f`). PostgreSQL 15+ creates `public` without
`CREATE` for `PUBLIC`, but a database whose schema dates from before 15 keeps the old grant; if either
is `t`, run `REVOKE CREATE ON SCHEMA public FROM PUBLIC;` as `doadmin`:

```sql
SELECT has_schema_privilege('fpc_web', 'public', 'CREATE'),
       has_schema_privilege('fpc_worker', 'public', 'CREATE');
```

Table and matview privileges for both roles:

```sql
SELECT r.rolname, c.relname, p.privilege
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN (VALUES ('fpc_web'), ('fpc_worker')) AS r(rolname)
CROSS JOIN (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE')) AS p(privilege)
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p', 'm')
  AND NOT (c.relkind = 'm' AND p.privilege <> 'SELECT')
  AND NOT has_table_privilege(r.rolname, c.oid, p.privilege);
```

Sequence privileges for both roles:

```sql
SELECT r.rolname, c.relname, p.privilege
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN (VALUES ('fpc_web'), ('fpc_worker')) AS r(rolname)
CROSS JOIN (VALUES ('USAGE'), ('SELECT'), ('UPDATE')) AS p(privilege)
WHERE n.nspname = 'public'
  AND c.relkind = 'S'
  AND NOT has_sequence_privilege(r.rolname, c.oid, p.privilege);
```

`MAINTAIN` for the worker on every table and both matviews:

```sql
SELECT c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p', 'm')
  AND NOT has_table_privilege('fpc_worker', c.oid, 'MAINTAIN');
```

Owners (the default privileges only apply to objects `doadmin` creates):

```sql
SELECT c.relname, c.relkind, pg_get_userbyid(c.relowner) AS owner
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p', 'm', 'S')
  AND pg_get_userbyid(c.relowner) <> 'doadmin';
```

Default privileges in place (expect rows for tables and sequences granted by `doadmin`):

```sql
SELECT pg_get_userbyid(defaclrole) AS creator, defaclobjtype, defaclacl FROM pg_default_acl;
```

Connections per role (as `fpc_readonly`; through PgBouncer these are server connections per pool
user). Use it before and after every rollout stage:

```sql
SELECT usename, state, count(*)
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY 1, 2
ORDER BY 1, 2;
```

A rolled-back smoke test as each role, connected through its pool (copy the connection string
from `doctl databases pool get <cluster-id> web --show`, or `worker`). `nextval` is not rolled
back and skips one id:

```sql
BEGIN;
SELECT current_user, current_setting('statement_timeout');
SELECT count(*) FROM collected_inks;
UPDATE users SET updated_at = updated_at WHERE id = (SELECT min(id) FROM users);
DELETE FROM collected_inks WHERE false;
INSERT INTO csp_reports SELECT * FROM csp_reports WHERE false;
SELECT nextval('csp_reports_id_seq');
ROLLBACK;
```

As the worker also (takes as long as the hourly refresh):

```sql
BEGIN;
REFRESH MATERIALIZED VIEW CONCURRENTLY pen_name_popularities;
ANALYZE pen_name_popularities;
ROLLBACK;
```

On a web machine after `WEB_DATABASE_URL` is set (the production image has no `psql`), open
`fly ssh console --process-group web` and run:

```sh
cd /app && DATABASE_URL="$WEB_DATABASE_URL" bin/rails runner 'c = ActiveRecord::Base.connection; p c.select_value("show statement_timeout"), c.select_value("select current_user")'
```

Expect `"15s"` and `"fpc_web"`. The same with `WORKER_DATABASE_URL` on a worker machine
(`--process-group worker`) should print `"0"` and `"fpc_worker"`.

## Pools and connection budget

The cluster allows 100 connections, 3 of them reserved for superusers (DigitalOcean's own
`postgres` role), so 97 for the pools and for direct connections. Neither `doadmin` nor
`fpc_readonly` is a superuser, so neither can use the reserved slots. It is unknown whether a pool
without a fixed user is sized per pool or per (user, database) pair, and DigitalOcean may cap the
sum of pool sizes at the backend limit. So each role has its own pool with a fixed user and
explicit size, and a pool is only created or grown after another one has been shrunk to make room.

Current layout (since 2026-11-15):

| Pool     | User         | Size | Used by                         |
| -------- | ------------ | ---- | ------------------------------- |
| `web`    | `fpc_web`    | 77   | Puma                            |
| `worker` | `fpc_worker` | 15   | Sidekiq                         |
| `pool`   | none         | 5    | `doadmin`: migrations, consoles |

That is all 97 connections. `fpc_readonly` connects directly (port 25060), not through a pool;
its connections only fail if the pools are ever saturated. PgBouncer opens server connections
only while a transaction runs: measured average concurrency before the switch (New Relic, 5-minute
buckets, 2026-11-05 to 11-10) peaked at 0.7 for web and 0.16 for the worker. Worker demand is
machines × 6 Sidekiq threads (default capsule `SIDEKIQ_CONCURRENCY` from `config/sidekiq.yml`, set
to 5 in `fly.toml`, plus the `slow` capsule's 1 in `config/initializers/sidekiq.rb`); `fly scale
show` lists the machines. Before changing a size, add up all pools and keep the total at or below
97.

`WEB_DATABASE_URL` and `WORKER_DATABASE_URL` are the pools' connection strings (same host and port
as `DATABASE_URL`, the pool name as the database path, the pool's user and password). Setting or
unsetting a Fly secret restarts the machines. Set them with `fly secrets import` on stdin so the
value appears neither in the shell's arguments nor in output, and only while no deploy is running
(a secrets change starts its own release).

```sh
doctl databases pool list <cluster-id>
doctl databases pool update <cluster-id> pool --db defaultdb --mode transaction --size 5
doctl databases pool update <cluster-id> web --db defaultdb --mode transaction --size 77 --user fpc_web
doctl databases pool get <cluster-id> web --format URI --no-header --show > tmp/.web_url   # mode 600, delete after use
```

`doctl databases pool create` prints the new pool's connection string **including the password**,
even without `--show`; send its output to `/dev/null` and fetch the string with `pool get --show`
into a file. A new pool takes about 20 seconds before PgBouncer accepts connections to it ("no such
database"). Resizing a pool did not drop open connections.

## Rollout history

Done on 2026-11-15, in this order; each step lists the total of pool sizes afterwards.

0. **Measure** (total 90: `pool` 90). Connections per role, worker machine count.
1. **Roles** (total 90). Users created, setup SQL and verification run as `doadmin`. The `public`
   schema still granted `CREATE` to `PUBLIC` (it predates PostgreSQL 15), so that grant was revoked;
   `doadmin` keeps `CREATE` as owner of `defaultdb` through `pg_database_owner`.
2. **Worker** (total 45: `pool` 30, `worker` 15). Shrank `pool`, created `worker`, smoke test,
   set `WORKER_DATABASE_URL`, ran `RefreshAutocompletePopularities` once by hand.
3. **Web** (total 90: `pool` 30, `worker` 15, `web` 45). Created `web`, smoke test (including a
   `pg_sleep(16)` that the timeout cancels), set `WEB_DATABASE_URL`.
4. **Resize** (total 97: `pool` 5, `worker` 15, `web` 77). Shrank `pool`, then grew `web`.

To check which role a process uses, look at the last statement of each backend as `fpc_readonly`
(`SELECT usename, state, state_change, left(query, 90) FROM pg_stat_activity`); web backends run
request queries. `/proc/<pid>/environ` is not a valid check for Puma: it shows the environment at
process start, not the `ENV["DATABASE_URL"]` that `config/puma.rb` sets.

Rollback: grow `pool` first (shrinking `web` or `worker` to stay within 97), then unset
`WEB_DATABASE_URL` or `WORKER_DATABASE_URL`.
