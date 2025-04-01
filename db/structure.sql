SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: blog_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blog_posts (
    id bigint NOT NULL,
    title text,
    body text,
    published_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blog_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blog_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blog_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blog_posts_id_seq OWNED BY public.blog_posts.id;


--
-- Name: brand_clusters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brand_clusters (
    id bigint NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    description text DEFAULT ''::text
);


--
-- Name: brand_clusters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.brand_clusters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: brand_clusters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.brand_clusters_id_seq OWNED BY public.brand_clusters.id;


--
-- Name: collected_inks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collected_inks (
    id integer NOT NULL,
    kind character varying,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    private boolean DEFAULT false,
    brand_name character varying(100) NOT NULL,
    line_name character varying(100) DEFAULT ''::character varying NOT NULL,
    ink_name character varying(100) NOT NULL,
    comment text DEFAULT ''::text,
    simplified_brand_name character varying(100),
    simplified_line_name character varying(100),
    simplified_ink_name character varying(100),
    color character varying(7) DEFAULT ''::character varying NOT NULL,
    swabbed boolean DEFAULT false NOT NULL,
    used boolean DEFAULT false NOT NULL,
    archived_on date,
    maker text DEFAULT ''::text,
    new_ink_name_id integer,
    currently_inked_count integer DEFAULT 0,
    private_comment text,
    micro_cluster_id bigint,
    cluster_color character varying(7) DEFAULT ''::character varying,
    tsv tsvector,
    CONSTRAINT collected_inks_cluster_color_null CHECK ((cluster_color IS NOT NULL))
);


--
-- Name: collected_inks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.collected_inks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collected_inks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.collected_inks_id_seq OWNED BY public.collected_inks.id;


--
-- Name: collected_pens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collected_pens (
    id bigint NOT NULL,
    brand character varying(100) NOT NULL,
    model character varying(100) NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    comment text,
    nib character varying(100),
    color character varying(100) DEFAULT ''::character varying NOT NULL,
    archived_on date,
    material text DEFAULT ''::text,
    price text DEFAULT ''::text,
    trim_color text DEFAULT ''::text,
    filling_system text DEFAULT ''::text,
    pens_micro_cluster_id bigint
);


--
-- Name: collected_pens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.collected_pens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: collected_pens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.collected_pens_id_seq OWNED BY public.collected_pens.id;


--
-- Name: currently_inked; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.currently_inked (
    id bigint NOT NULL,
    comment text,
    collected_ink_id bigint NOT NULL,
    collected_pen_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id bigint NOT NULL,
    archived_on date,
    inked_on date NOT NULL,
    nib character varying(100) DEFAULT ''::character varying
);


--
-- Name: currently_inked_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.currently_inked_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: currently_inked_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.currently_inked_id_seq OWNED BY public.currently_inked.id;


--
-- Name: gutentag_taggings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gutentag_taggings (
    id bigint NOT NULL,
    tag_id integer NOT NULL,
    taggable_id integer NOT NULL,
    taggable_type character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: gutentag_taggings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gutentag_taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gutentag_taggings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gutentag_taggings_id_seq OWNED BY public.gutentag_taggings.id;


--
-- Name: gutentag_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gutentag_tags (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    taggings_count integer DEFAULT 0 NOT NULL
);


--
-- Name: gutentag_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gutentag_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gutentag_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gutentag_tags_id_seq OWNED BY public.gutentag_tags.id;


--
-- Name: ink_brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ink_brands (
    id bigint NOT NULL,
    simplified_name text,
    popular_name text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: ink_brands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ink_brands_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ink_brands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ink_brands_id_seq OWNED BY public.ink_brands.id;


--
-- Name: ink_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ink_embeddings (
    id bigint NOT NULL,
    content text NOT NULL,
    embedding public.vector(1536),
    owner_type character varying NOT NULL,
    owner_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ink_embeddings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ink_embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ink_embeddings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ink_embeddings_id_seq OWNED BY public.ink_embeddings.id;


--
-- Name: ink_review_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ink_review_submissions (
    id bigint NOT NULL,
    url text NOT NULL,
    macro_cluster_id bigint NOT NULL,
    user_id bigint NOT NULL,
    ink_review_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    unfurling_errors text,
    html text
);


--
-- Name: ink_review_submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ink_review_submissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ink_review_submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ink_review_submissions_id_seq OWNED BY public.ink_review_submissions.id;


--
-- Name: ink_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ink_reviews (
    id bigint NOT NULL,
    title text NOT NULL,
    url text NOT NULL,
    description text,
    image text NOT NULL,
    macro_cluster_id bigint NOT NULL,
    rejected_at timestamp without time zone,
    approved_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    host text,
    author text,
    auto_approved boolean DEFAULT false,
    you_tube_channel_id bigint
);


--
-- Name: ink_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ink_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ink_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ink_reviews_id_seq OWNED BY public.ink_reviews.id;


--
-- Name: leader_board_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leader_board_rows (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    type character varying,
    value integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: leader_board_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.leader_board_rows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: leader_board_rows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.leader_board_rows_id_seq OWNED BY public.leader_board_rows.id;


--
-- Name: macro_clusters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.macro_clusters (
    id bigint NOT NULL,
    brand_name character varying DEFAULT ''::character varying,
    line_name character varying DEFAULT ''::character varying,
    ink_name character varying DEFAULT ''::character varying,
    color character varying(7) DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    brand_cluster_id bigint,
    description text DEFAULT ''::text,
    tags text[] DEFAULT '{}'::text[]
);


--
-- Name: macro_clusters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.macro_clusters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: macro_clusters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.macro_clusters_id_seq OWNED BY public.macro_clusters.id;


--
-- Name: micro_clusters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.micro_clusters (
    id bigint NOT NULL,
    simplified_brand_name text NOT NULL,
    simplified_line_name text DEFAULT ''::text,
    simplified_ink_name text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    macro_cluster_id bigint,
    ignored boolean DEFAULT false
);


--
-- Name: micro_clusters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.micro_clusters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: micro_clusters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.micro_clusters_id_seq OWNED BY public.micro_clusters.id;


--
-- Name: new_ink_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.new_ink_names (
    id bigint NOT NULL,
    simplified_name text NOT NULL,
    popular_name text,
    ink_brand_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    popular_line_name text DEFAULT ''::text,
    color character varying(7) DEFAULT ''::character varying NOT NULL
);


--
-- Name: new_ink_names_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.new_ink_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: new_ink_names_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.new_ink_names_id_seq OWNED BY public.new_ink_names.id;


--
-- Name: pen_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pen_embeddings (
    id bigint NOT NULL,
    content text NOT NULL,
    embedding public.vector(1536),
    owner_type character varying NOT NULL,
    owner_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pen_embeddings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pen_embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pen_embeddings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pen_embeddings_id_seq OWNED BY public.pen_embeddings.id;


--
-- Name: pens_brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pens_brands (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pens_brands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pens_brands_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pens_brands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pens_brands_id_seq OWNED BY public.pens_brands.id;


--
-- Name: pens_micro_clusters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pens_micro_clusters (
    id bigint NOT NULL,
    simplified_brand text NOT NULL,
    simplified_model text NOT NULL,
    simplified_color text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    ignored boolean DEFAULT false,
    pens_model_variant_id bigint
);


--
-- Name: pens_micro_clusters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pens_micro_clusters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pens_micro_clusters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pens_micro_clusters_id_seq OWNED BY public.pens_micro_clusters.id;


--
-- Name: pens_model_micro_clusters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pens_model_micro_clusters (
    id bigint NOT NULL,
    simplified_brand text NOT NULL,
    simplified_model text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    pens_model_id bigint,
    ignored boolean DEFAULT false
);


--
-- Name: pens_model_micro_clusters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pens_model_micro_clusters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pens_model_micro_clusters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pens_model_micro_clusters_id_seq OWNED BY public.pens_model_micro_clusters.id;


--
-- Name: pens_model_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pens_model_variants (
    id bigint NOT NULL,
    brand text NOT NULL,
    model text NOT NULL,
    color text DEFAULT ''::text NOT NULL,
    material text DEFAULT ''::text NOT NULL,
    trim_color text DEFAULT ''::text NOT NULL,
    filling_system text DEFAULT ''::text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    pens_model_micro_cluster_id bigint
);


--
-- Name: pens_model_variants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pens_model_variants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pens_model_variants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pens_model_variants_id_seq OWNED BY public.pens_model_variants.id;


--
-- Name: pens_models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pens_models (
    id bigint NOT NULL,
    brand text NOT NULL,
    model text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    pens_brand_id bigint
);


--
-- Name: pens_models_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pens_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pens_models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pens_models_id_seq OWNED BY public.pens_models.id;


--
-- Name: reading_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reading_statuses (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    blog_post_id bigint NOT NULL,
    read boolean DEFAULT false NOT NULL,
    dismissed boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: reading_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reading_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reading_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reading_statuses_id_seq OWNED BY public.reading_statuses.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: usage_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_records (
    id bigint NOT NULL,
    currently_inked_id bigint NOT NULL,
    used_on date NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: usage_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usage_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usage_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usage_records_id_seq OWNED BY public.usage_records.id;


--
-- Name: user_agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_agents (
    id bigint NOT NULL,
    name character varying,
    raw_name character varying,
    day date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_agents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_agents_id_seq OWNED BY public.user_agents.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip inet,
    last_sign_in_ip inet,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying(100),
    confirmation_token character varying,
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    unconfirmed_email character varying,
    blurb text DEFAULT ''::text,
    patron boolean DEFAULT false,
    time_zone character varying,
    bot boolean DEFAULT false,
    sign_up_user_agent text,
    sign_up_ip character varying,
    bot_reason character varying,
    admin boolean DEFAULT false,
    review_blurb boolean DEFAULT false,
    spam boolean DEFAULT false,
    spam_reason character varying DEFAULT ''::character varying
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.versions (
    id bigint NOT NULL,
    item_type character varying NOT NULL,
    item_id bigint NOT NULL,
    event character varying NOT NULL,
    whodunnit character varying,
    object text,
    created_at timestamp(6) without time zone,
    object_changes text
);


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.versions_id_seq OWNED BY public.versions.id;


--
-- Name: you_tube_channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.you_tube_channels (
    id bigint NOT NULL,
    channel_id character varying NOT NULL,
    back_catalog_imported boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: you_tube_channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.you_tube_channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: you_tube_channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.you_tube_channels_id_seq OWNED BY public.you_tube_channels.id;


--
-- Name: blog_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_posts ALTER COLUMN id SET DEFAULT nextval('public.blog_posts_id_seq'::regclass);


--
-- Name: brand_clusters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_clusters ALTER COLUMN id SET DEFAULT nextval('public.brand_clusters_id_seq'::regclass);


--
-- Name: collected_inks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_inks ALTER COLUMN id SET DEFAULT nextval('public.collected_inks_id_seq'::regclass);


--
-- Name: collected_pens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_pens ALTER COLUMN id SET DEFAULT nextval('public.collected_pens_id_seq'::regclass);


--
-- Name: currently_inked id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.currently_inked ALTER COLUMN id SET DEFAULT nextval('public.currently_inked_id_seq'::regclass);


--
-- Name: gutentag_taggings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gutentag_taggings ALTER COLUMN id SET DEFAULT nextval('public.gutentag_taggings_id_seq'::regclass);


--
-- Name: gutentag_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gutentag_tags ALTER COLUMN id SET DEFAULT nextval('public.gutentag_tags_id_seq'::regclass);


--
-- Name: ink_brands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_brands ALTER COLUMN id SET DEFAULT nextval('public.ink_brands_id_seq'::regclass);


--
-- Name: ink_embeddings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_embeddings ALTER COLUMN id SET DEFAULT nextval('public.ink_embeddings_id_seq'::regclass);


--
-- Name: ink_review_submissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_review_submissions ALTER COLUMN id SET DEFAULT nextval('public.ink_review_submissions_id_seq'::regclass);


--
-- Name: ink_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_reviews ALTER COLUMN id SET DEFAULT nextval('public.ink_reviews_id_seq'::regclass);


--
-- Name: leader_board_rows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leader_board_rows ALTER COLUMN id SET DEFAULT nextval('public.leader_board_rows_id_seq'::regclass);


--
-- Name: macro_clusters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.macro_clusters ALTER COLUMN id SET DEFAULT nextval('public.macro_clusters_id_seq'::regclass);


--
-- Name: micro_clusters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.micro_clusters ALTER COLUMN id SET DEFAULT nextval('public.micro_clusters_id_seq'::regclass);


--
-- Name: new_ink_names id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.new_ink_names ALTER COLUMN id SET DEFAULT nextval('public.new_ink_names_id_seq'::regclass);


--
-- Name: pen_embeddings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pen_embeddings ALTER COLUMN id SET DEFAULT nextval('public.pen_embeddings_id_seq'::regclass);


--
-- Name: pens_brands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_brands ALTER COLUMN id SET DEFAULT nextval('public.pens_brands_id_seq'::regclass);


--
-- Name: pens_micro_clusters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_micro_clusters ALTER COLUMN id SET DEFAULT nextval('public.pens_micro_clusters_id_seq'::regclass);


--
-- Name: pens_model_micro_clusters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_model_micro_clusters ALTER COLUMN id SET DEFAULT nextval('public.pens_model_micro_clusters_id_seq'::regclass);


--
-- Name: pens_model_variants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_model_variants ALTER COLUMN id SET DEFAULT nextval('public.pens_model_variants_id_seq'::regclass);


--
-- Name: pens_models id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_models ALTER COLUMN id SET DEFAULT nextval('public.pens_models_id_seq'::regclass);


--
-- Name: reading_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reading_statuses ALTER COLUMN id SET DEFAULT nextval('public.reading_statuses_id_seq'::regclass);


--
-- Name: usage_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_records ALTER COLUMN id SET DEFAULT nextval('public.usage_records_id_seq'::regclass);


--
-- Name: user_agents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_agents ALTER COLUMN id SET DEFAULT nextval('public.user_agents_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);


--
-- Name: you_tube_channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.you_tube_channels ALTER COLUMN id SET DEFAULT nextval('public.you_tube_channels_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: blog_posts blog_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_posts
    ADD CONSTRAINT blog_posts_pkey PRIMARY KEY (id);


--
-- Name: brand_clusters brand_clusters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_clusters
    ADD CONSTRAINT brand_clusters_pkey PRIMARY KEY (id);


--
-- Name: collected_inks collected_inks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_inks
    ADD CONSTRAINT collected_inks_pkey PRIMARY KEY (id);


--
-- Name: collected_pens collected_pens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_pens
    ADD CONSTRAINT collected_pens_pkey PRIMARY KEY (id);


--
-- Name: currently_inked currently_inked_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.currently_inked
    ADD CONSTRAINT currently_inked_pkey PRIMARY KEY (id);


--
-- Name: gutentag_taggings gutentag_taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gutentag_taggings
    ADD CONSTRAINT gutentag_taggings_pkey PRIMARY KEY (id);


--
-- Name: gutentag_tags gutentag_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gutentag_tags
    ADD CONSTRAINT gutentag_tags_pkey PRIMARY KEY (id);


--
-- Name: ink_brands ink_brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_brands
    ADD CONSTRAINT ink_brands_pkey PRIMARY KEY (id);


--
-- Name: ink_embeddings ink_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_embeddings
    ADD CONSTRAINT ink_embeddings_pkey PRIMARY KEY (id);


--
-- Name: ink_review_submissions ink_review_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_review_submissions
    ADD CONSTRAINT ink_review_submissions_pkey PRIMARY KEY (id);


--
-- Name: ink_reviews ink_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_reviews
    ADD CONSTRAINT ink_reviews_pkey PRIMARY KEY (id);


--
-- Name: leader_board_rows leader_board_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leader_board_rows
    ADD CONSTRAINT leader_board_rows_pkey PRIMARY KEY (id);


--
-- Name: macro_clusters macro_clusters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.macro_clusters
    ADD CONSTRAINT macro_clusters_pkey PRIMARY KEY (id);


--
-- Name: micro_clusters micro_clusters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.micro_clusters
    ADD CONSTRAINT micro_clusters_pkey PRIMARY KEY (id);


--
-- Name: new_ink_names new_ink_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.new_ink_names
    ADD CONSTRAINT new_ink_names_pkey PRIMARY KEY (id);


--
-- Name: pen_embeddings pen_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pen_embeddings
    ADD CONSTRAINT pen_embeddings_pkey PRIMARY KEY (id);


--
-- Name: pens_brands pens_brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_brands
    ADD CONSTRAINT pens_brands_pkey PRIMARY KEY (id);


--
-- Name: pens_micro_clusters pens_micro_clusters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_micro_clusters
    ADD CONSTRAINT pens_micro_clusters_pkey PRIMARY KEY (id);


--
-- Name: pens_model_micro_clusters pens_model_micro_clusters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_model_micro_clusters
    ADD CONSTRAINT pens_model_micro_clusters_pkey PRIMARY KEY (id);


--
-- Name: pens_model_variants pens_model_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_model_variants
    ADD CONSTRAINT pens_model_variants_pkey PRIMARY KEY (id);


--
-- Name: pens_models pens_models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_models
    ADD CONSTRAINT pens_models_pkey PRIMARY KEY (id);


--
-- Name: reading_statuses reading_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reading_statuses
    ADD CONSTRAINT reading_statuses_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: usage_records usage_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_records
    ADD CONSTRAINT usage_records_pkey PRIMARY KEY (id);


--
-- Name: user_agents user_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_agents
    ADD CONSTRAINT user_agents_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: you_tube_channels you_tube_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.you_tube_channels
    ADD CONSTRAINT you_tube_channels_pkey PRIMARY KEY (id);


--
-- Name: idx_on_brand_model_color_material_trim_color_fillin_c4996a6771; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_brand_model_color_material_trim_color_fillin_c4996a6771 ON public.pens_model_variants USING btree (brand, model, color, material, trim_color, filling_system);


--
-- Name: idx_on_simplified_brand_simplified_model_70c232c961; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_simplified_brand_simplified_model_70c232c961 ON public.pens_model_micro_clusters USING btree (simplified_brand, simplified_model);


--
-- Name: idx_on_simplified_brand_simplified_model_simplified_b6b51aca41; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_simplified_brand_simplified_model_simplified_b6b51aca41 ON public.pens_micro_clusters USING btree (simplified_brand, simplified_model, simplified_color);


--
-- Name: index_brand_clusters_on_description; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brand_clusters_on_description ON public.brand_clusters USING btree (description);


--
-- Name: index_brand_clusters_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_brand_clusters_on_name ON public.brand_clusters USING btree (name);


--
-- Name: index_collected_inks_on_archived_on_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_archived_on_and_user_id ON public.collected_inks USING btree (archived_on, user_id);


--
-- Name: index_collected_inks_on_brand_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_brand_name ON public.collected_inks USING btree (brand_name);


--
-- Name: index_collected_inks_on_ink_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_ink_name ON public.collected_inks USING btree (ink_name);


--
-- Name: index_collected_inks_on_line_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_line_name ON public.collected_inks USING btree (line_name);


--
-- Name: index_collected_inks_on_micro_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_micro_cluster_id ON public.collected_inks USING btree (micro_cluster_id);


--
-- Name: index_collected_inks_on_private; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_private ON public.collected_inks USING btree (private);


--
-- Name: index_collected_inks_on_simplified_ink_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_simplified_ink_name ON public.collected_inks USING btree (simplified_ink_name);


--
-- Name: index_collected_inks_on_tsv; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_tsv ON public.collected_inks USING gin (tsv);


--
-- Name: index_collected_pens_on_brand; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_pens_on_brand ON public.collected_pens USING gist (brand public.gist_trgm_ops);


--
-- Name: index_collected_pens_on_model; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_pens_on_model ON public.collected_pens USING gist (model public.gist_trgm_ops);


--
-- Name: index_collected_pens_on_pens_micro_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_pens_on_pens_micro_cluster_id ON public.collected_pens USING btree (pens_micro_cluster_id);


--
-- Name: index_collected_pens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_pens_on_user_id ON public.collected_pens USING btree (user_id);


--
-- Name: index_currently_inked_on_collected_ink_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_currently_inked_on_collected_ink_id ON public.currently_inked USING btree (collected_ink_id);


--
-- Name: index_currently_inked_on_collected_pen_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_currently_inked_on_collected_pen_id ON public.currently_inked USING btree (collected_pen_id);


--
-- Name: index_currently_inked_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_currently_inked_on_user_id ON public.currently_inked USING btree (user_id);


--
-- Name: index_gutentag_taggings_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gutentag_taggings_on_tag_id ON public.gutentag_taggings USING btree (tag_id);


--
-- Name: index_gutentag_tags_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_gutentag_tags_on_name ON public.gutentag_tags USING btree (name);


--
-- Name: index_gutentag_tags_on_taggings_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gutentag_tags_on_taggings_count ON public.gutentag_tags USING btree (taggings_count);


--
-- Name: index_ink_brands_on_simplified_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ink_brands_on_simplified_name ON public.ink_brands USING btree (simplified_name);


--
-- Name: index_ink_embeddings_on_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ink_embeddings_on_embedding ON public.ink_embeddings USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: index_ink_embeddings_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ink_embeddings_on_owner ON public.ink_embeddings USING btree (owner_type, owner_id);


--
-- Name: index_ink_embeddings_on_owner_type_and_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ink_embeddings_on_owner_type_and_owner_id ON public.ink_embeddings USING btree (owner_type, owner_id);


--
-- Name: index_ink_review_submissions_on_ink_review_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ink_review_submissions_on_ink_review_id ON public.ink_review_submissions USING btree (ink_review_id);


--
-- Name: index_ink_review_submissions_on_macro_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ink_review_submissions_on_macro_cluster_id ON public.ink_review_submissions USING btree (macro_cluster_id);


--
-- Name: index_ink_review_submissions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ink_review_submissions_on_user_id ON public.ink_review_submissions USING btree (user_id);


--
-- Name: index_ink_reviews_on_macro_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ink_reviews_on_macro_cluster_id ON public.ink_reviews USING btree (macro_cluster_id);


--
-- Name: index_ink_reviews_on_url_and_macro_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ink_reviews_on_url_and_macro_cluster_id ON public.ink_reviews USING btree (url, macro_cluster_id);


--
-- Name: index_leader_board_rows_on_type_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_leader_board_rows_on_type_and_user_id ON public.leader_board_rows USING btree (type, user_id);


--
-- Name: index_leader_board_rows_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leader_board_rows_on_user_id ON public.leader_board_rows USING btree (user_id);


--
-- Name: index_leader_board_rows_on_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leader_board_rows_on_value ON public.leader_board_rows USING btree (value);


--
-- Name: index_macro_clusters_on_brand_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_macro_clusters_on_brand_cluster_id ON public.macro_clusters USING btree (brand_cluster_id);


--
-- Name: index_macro_clusters_on_brand_name_and_line_name_and_ink_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_macro_clusters_on_brand_name_and_line_name_and_ink_name ON public.macro_clusters USING btree (brand_name, line_name, ink_name);


--
-- Name: index_macro_clusters_on_description; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_macro_clusters_on_description ON public.macro_clusters USING btree (description);


--
-- Name: index_macro_clusters_on_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_macro_clusters_on_tags ON public.macro_clusters USING gin (tags);


--
-- Name: index_micro_clusters_on_macro_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_micro_clusters_on_macro_cluster_id ON public.micro_clusters USING btree (macro_cluster_id);


--
-- Name: index_new_ink_names_on_popular_line_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_new_ink_names_on_popular_line_name ON public.new_ink_names USING btree (popular_line_name);


--
-- Name: index_new_ink_names_on_popular_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_new_ink_names_on_popular_name ON public.new_ink_names USING btree (popular_name);


--
-- Name: index_new_ink_names_on_simplified_name_and_ink_brand_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_new_ink_names_on_simplified_name_and_ink_brand_id ON public.new_ink_names USING btree (simplified_name, ink_brand_id);


--
-- Name: index_pen_embeddings_on_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pen_embeddings_on_embedding ON public.pen_embeddings USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: index_pen_embeddings_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pen_embeddings_on_owner ON public.pen_embeddings USING btree (owner_type, owner_id);


--
-- Name: index_pen_embeddings_on_owner_type_and_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pen_embeddings_on_owner_type_and_owner_id ON public.pen_embeddings USING btree (owner_type, owner_id);


--
-- Name: index_pens_brands_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pens_brands_on_name ON public.pens_brands USING btree (name);


--
-- Name: index_pens_micro_clusters_on_pens_model_variant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pens_micro_clusters_on_pens_model_variant_id ON public.pens_micro_clusters USING btree (pens_model_variant_id);


--
-- Name: index_pens_model_micro_clusters_on_pens_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pens_model_micro_clusters_on_pens_model_id ON public.pens_model_micro_clusters USING btree (pens_model_id);


--
-- Name: index_pens_model_variants_on_pens_model_micro_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pens_model_variants_on_pens_model_micro_cluster_id ON public.pens_model_variants USING btree (pens_model_micro_cluster_id);


--
-- Name: index_pens_models_on_brand_and_model; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pens_models_on_brand_and_model ON public.pens_models USING btree (brand, model);


--
-- Name: index_pens_models_on_pens_brand_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pens_models_on_pens_brand_id ON public.pens_models USING btree (pens_brand_id);


--
-- Name: index_reading_statuses_on_blog_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reading_statuses_on_blog_post_id ON public.reading_statuses USING btree (blog_post_id);


--
-- Name: index_reading_statuses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reading_statuses_on_user_id ON public.reading_statuses USING btree (user_id);


--
-- Name: index_usage_records_on_currently_inked_id_and_used_on; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_records_on_currently_inked_id_and_used_on ON public.usage_records USING btree (currently_inked_id, used_on);


--
-- Name: index_user_agents_on_name_and_day; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_agents_on_name_and_day ON public.user_agents USING btree (name, day);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_spam; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_spam ON public.users USING btree (spam);


--
-- Name: index_users_on_spam_reason; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_spam_reason ON public.users USING btree (spam_reason);


--
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_item_type_and_item_id ON public.versions USING btree (item_type, item_id);


--
-- Name: index_you_tube_channels_on_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_you_tube_channels_on_channel_id ON public.you_tube_channels USING btree (channel_id);


--
-- Name: unique_micro_clusters; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_micro_clusters ON public.micro_clusters USING btree (simplified_brand_name, simplified_line_name, simplified_ink_name);


--
-- Name: unique_taggings; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_taggings ON public.gutentag_taggings USING btree (taggable_type, taggable_id, tag_id);


--
-- Name: collected_inks tsvectorupdate_ci; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tsvectorupdate_ci BEFORE INSERT OR UPDATE ON public.collected_inks FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('tsv', 'pg_catalog.english', 'brand_name', 'line_name', 'ink_name');


--
-- Name: collected_pens fk_rails_0a20d528f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_pens
    ADD CONSTRAINT fk_rails_0a20d528f9 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: currently_inked fk_rails_0e11972aec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.currently_inked
    ADD CONSTRAINT fk_rails_0e11972aec FOREIGN KEY (collected_pen_id) REFERENCES public.collected_pens(id);


--
-- Name: pens_model_micro_clusters fk_rails_15b953e2a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_model_micro_clusters
    ADD CONSTRAINT fk_rails_15b953e2a0 FOREIGN KEY (pens_model_id) REFERENCES public.pens_models(id);


--
-- Name: reading_statuses fk_rails_17ee7cb2c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reading_statuses
    ADD CONSTRAINT fk_rails_17ee7cb2c4 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: macro_clusters fk_rails_4b634dc145; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.macro_clusters
    ADD CONSTRAINT fk_rails_4b634dc145 FOREIGN KEY (brand_cluster_id) REFERENCES public.brand_clusters(id);


--
-- Name: ink_review_submissions fk_rails_4ffd484639; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_review_submissions
    ADD CONSTRAINT fk_rails_4ffd484639 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: ink_reviews fk_rails_5569a8a900; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_reviews
    ADD CONSTRAINT fk_rails_5569a8a900 FOREIGN KEY (you_tube_channel_id) REFERENCES public.you_tube_channels(id);


--
-- Name: ink_review_submissions fk_rails_56df03bea8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_review_submissions
    ADD CONSTRAINT fk_rails_56df03bea8 FOREIGN KEY (ink_review_id) REFERENCES public.ink_reviews(id);


--
-- Name: collected_inks fk_rails_6e15b56fd1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_inks
    ADD CONSTRAINT fk_rails_6e15b56fd1 FOREIGN KEY (new_ink_name_id) REFERENCES public.new_ink_names(id);


--
-- Name: pens_models fk_rails_706cba2d15; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_models
    ADD CONSTRAINT fk_rails_706cba2d15 FOREIGN KEY (pens_brand_id) REFERENCES public.pens_brands(id);


--
-- Name: ink_reviews fk_rails_7ce1cd1ba7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_reviews
    ADD CONSTRAINT fk_rails_7ce1cd1ba7 FOREIGN KEY (macro_cluster_id) REFERENCES public.macro_clusters(id);


--
-- Name: collected_inks fk_rails_86cd529415; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_inks
    ADD CONSTRAINT fk_rails_86cd529415 FOREIGN KEY (micro_cluster_id) REFERENCES public.micro_clusters(id);


--
-- Name: pens_model_variants fk_rails_9098e51c82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_model_variants
    ADD CONSTRAINT fk_rails_9098e51c82 FOREIGN KEY (pens_model_micro_cluster_id) REFERENCES public.pens_model_micro_clusters(id);


--
-- Name: micro_clusters fk_rails_9c1c47af02; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.micro_clusters
    ADD CONSTRAINT fk_rails_9c1c47af02 FOREIGN KEY (macro_cluster_id) REFERENCES public.macro_clusters(id);


--
-- Name: currently_inked fk_rails_9cbc8f0e87; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.currently_inked
    ADD CONSTRAINT fk_rails_9cbc8f0e87 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: leader_board_rows fk_rails_9ea6f9eee3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leader_board_rows
    ADD CONSTRAINT fk_rails_9ea6f9eee3 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: collected_pens fk_rails_a020b0d7bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_pens
    ADD CONSTRAINT fk_rails_a020b0d7bb FOREIGN KEY (pens_micro_cluster_id) REFERENCES public.pens_micro_clusters(id);


--
-- Name: new_ink_names fk_rails_abf549b471; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.new_ink_names
    ADD CONSTRAINT fk_rails_abf549b471 FOREIGN KEY (ink_brand_id) REFERENCES public.ink_brands(id);


--
-- Name: reading_statuses fk_rails_ac96400e2d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reading_statuses
    ADD CONSTRAINT fk_rails_ac96400e2d FOREIGN KEY (blog_post_id) REFERENCES public.blog_posts(id);


--
-- Name: usage_records fk_rails_c4d19d072d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_records
    ADD CONSTRAINT fk_rails_c4d19d072d FOREIGN KEY (currently_inked_id) REFERENCES public.currently_inked(id);


--
-- Name: pens_micro_clusters fk_rails_d7b7d193b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pens_micro_clusters
    ADD CONSTRAINT fk_rails_d7b7d193b7 FOREIGN KEY (pens_model_variant_id) REFERENCES public.pens_model_variants(id);


--
-- Name: ink_review_submissions fk_rails_ee836511b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_review_submissions
    ADD CONSTRAINT fk_rails_ee836511b9 FOREIGN KEY (macro_cluster_id) REFERENCES public.macro_clusters(id);


--
-- Name: currently_inked fk_rails_f7785b2096; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.currently_inked
    ADD CONSTRAINT fk_rails_f7785b2096 FOREIGN KEY (collected_ink_id) REFERENCES public.collected_inks(id);


--
-- Name: collected_inks fk_rails_ff3da6909f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_inks
    ADD CONSTRAINT fk_rails_ff3da6909f FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20250401120318'),
('20250331124026'),
('20250331082810'),
('20250209193211'),
('20250206124945'),
('20250206102705'),
('20250206102130'),
('20250107083051'),
('20241228204210'),
('20241228202733'),
('20241211115823'),
('20241114144808'),
('20240916060008'),
('20240911151651'),
('20240911151335'),
('20240911074804'),
('20240821105438'),
('20240811095146'),
('20240612132332'),
('20240612105817'),
('20240612105640'),
('20240610132220'),
('20240610132035'),
('20240426054336'),
('20240426054203'),
('20240426054034'),
('20240426053842'),
('20240419133046'),
('20240419132642'),
('20240419132458'),
('20240418080146'),
('20240418075713'),
('20240316093246'),
('20240229065535'),
('20240227130854'),
('20240227125139'),
('20240227123255'),
('20240227082554'),
('20231205152235'),
('20230729172114'),
('20230728091425'),
('20230728091424'),
('20230728091314'),
('20230728091234'),
('20230707095306'),
('20230707093107'),
('20230707093023'),
('20220410081621'),
('20220410080853'),
('20211222103755'),
('20211217111324'),
('20211213131530'),
('20211211155425'),
('20211210105355'),
('20211205123842'),
('20211203123031'),
('20211203095418'),
('20211203085611'),
('20211008130613'),
('20211008130446'),
('20211008130445'),
('20211008130444'),
('20210521072307'),
('20210422204021'),
('20210420100740'),
('20210419191331'),
('20210415062021'),
('20201007070202'),
('20201002133409'),
('20200930124526'),
('20200930122807'),
('20200717152302'),
('20200501112723'),
('20200501084459'),
('20200501084410'),
('20200501084123'),
('20200501083855'),
('20200425193609'),
('20200413140510'),
('20200413140420'),
('20200411111714'),
('20200411110348'),
('20200411110158'),
('20200411110116'),
('20200411105910'),
('20200410182613'),
('20200408173146'),
('20200314133313'),
('20200312201442'),
('20200312201035'),
('20200225141017'),
('20200225125327'),
('20200203072140'),
('20190508191145'),
('20190325092019'),
('20190325084946'),
('20190325074641'),
('20181004061130'),
('20181001104907'),
('20180919200529'),
('20180918051116'),
('20180915181321'),
('20180915175351'),
('20180914062442'),
('20180914060945'),
('20180907143946'),
('20180801054458'),
('20180726061424'),
('20180726060907'),
('20180726060548'),
('20180507063532'),
('20180507062204'),
('20180417144312'),
('20180227181153'),
('20180218193150'),
('20180218190002'),
('20180218142925'),
('20180217122007'),
('20180216175049'),
('20180214072802'),
('20180212144350'),
('20180212131314'),
('20180212114732'),
('20180212111548'),
('20180212105620'),
('20180210084805'),
('20180209065827'),
('20180206073008'),
('20180205161551'),
('20180205072218'),
('20180205071528'),
('20180205070500'),
('20180129071525'),
('20171020061358'),
('20171020061129'),
('20171020060546'),
('20171019155404'),
('20171019062617'),
('20171019061342'),
('20171006062828'),
('20171006061817'),
('20170811073112'),
('20170713111102'),
('20170710185856'),
('20170707150917'),
('20170627114616'),
('20170621145107'),
('20170614061536'),
('20170612134415'),
('20170531055244'),
('20170524060841'),
('20170524060617'),
('20170524055721'),
('20170523152957'),
('20170523152730'),
('20170521190332'),
('20170521185337'),
('20170521181851'),
('20170519062041'),
('20170502061318'),
('20170502060458'),
('20170502055847'),
('20170424062404');

