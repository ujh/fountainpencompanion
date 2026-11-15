GRANT CONNECT ON DATABASE defaultdb TO fpc_ink_review;
GRANT USAGE ON SCHEMA public TO fpc_ink_review;

GRANT SELECT ON public.macro_clusters, public.micro_clusters, public.ink_embeddings TO fpc_ink_review;
GRANT SELECT (user_id, micro_cluster_id, brand_name, line_name, ink_name, color)
  ON public.collected_inks TO fpc_ink_review;
GRANT SELECT (id, name, owner_type, owner_id, state, agent_approved, extra_data, created_at)
  ON public.agent_logs TO fpc_ink_review;

ALTER ROLE fpc_ink_review SET default_transaction_read_only = on;
ALTER ROLE fpc_ink_review SET statement_timeout = '120s';
ALTER ROLE fpc_ink_review CONNECTION LIMIT 6;
