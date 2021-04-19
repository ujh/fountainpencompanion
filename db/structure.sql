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
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admins (
    id bigint NOT NULL,
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
    confirmation_token character varying,
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    unconfirmed_email character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: admins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admins_id_seq OWNED BY public.admins.id;


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
    updated_at timestamp(6) without time zone NOT NULL
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
    color character varying(100),
    archived_on date
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
-- Name: friendships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendships (
    id bigint NOT NULL,
    sender_id bigint NOT NULL,
    friend_id bigint NOT NULL,
    approved boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: friendships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.friendships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friendships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.friendships_id_seq OWNED BY public.friendships.id;


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
    brand_cluster_id bigint
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
    sign_up_user_agent text
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
-- Name: admins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins ALTER COLUMN id SET DEFAULT nextval('public.admins_id_seq'::regclass);


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
-- Name: friendships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships ALTER COLUMN id SET DEFAULT nextval('public.friendships_id_seq'::regclass);


--
-- Name: ink_brands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_brands ALTER COLUMN id SET DEFAULT nextval('public.ink_brands_id_seq'::regclass);


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
-- Name: reading_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reading_statuses ALTER COLUMN id SET DEFAULT nextval('public.reading_statuses_id_seq'::regclass);


--
-- Name: usage_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_records ALTER COLUMN id SET DEFAULT nextval('public.usage_records_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


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
-- Name: friendships friendships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_pkey PRIMARY KEY (id);


--
-- Name: ink_brands ink_brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ink_brands
    ADD CONSTRAINT ink_brands_pkey PRIMARY KEY (id);


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
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_admins_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admins_on_email ON public.admins USING btree (email);


--
-- Name: index_admins_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admins_on_reset_password_token ON public.admins USING btree (reset_password_token);


--
-- Name: index_brand_clusters_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_brand_clusters_on_name ON public.brand_clusters USING btree (name);


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
-- Name: index_collected_inks_on_simplified_ink_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_simplified_ink_name ON public.collected_inks USING btree (simplified_ink_name);


--
-- Name: index_collected_inks_on_tsv; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collected_inks_on_tsv ON public.collected_inks USING gin (tsv);


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
-- Name: index_friendships_on_friend_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendships_on_friend_id ON public.friendships USING btree (friend_id);


--
-- Name: index_friendships_on_sender_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendships_on_sender_id ON public.friendships USING btree (sender_id);


--
-- Name: index_ink_brands_on_simplified_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ink_brands_on_simplified_name ON public.ink_brands USING btree (simplified_name);


--
-- Name: index_macro_clusters_on_brand_cluster_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_macro_clusters_on_brand_cluster_id ON public.macro_clusters USING btree (brand_cluster_id);


--
-- Name: index_macro_clusters_on_brand_name_and_line_name_and_ink_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_macro_clusters_on_brand_name_and_line_name_and_ink_name ON public.macro_clusters USING btree (brand_name, line_name, ink_name);


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
-- Name: index_reading_statuses_on_blog_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reading_statuses_on_blog_post_id ON public.reading_statuses USING btree (blog_post_id);


--
-- Name: index_reading_statuses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reading_statuses_on_user_id ON public.reading_statuses USING btree (user_id);


--
-- Name: index_usage_records_on_currently_inked_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_records_on_currently_inked_id ON public.usage_records USING btree (currently_inked_id);


--
-- Name: index_usage_records_on_currently_inked_id_and_used_on; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_records_on_currently_inked_id_and_used_on ON public.usage_records USING btree (currently_inked_id, used_on);


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
-- Name: unique_micro_clusters; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_micro_clusters ON public.micro_clusters USING btree (simplified_brand_name, simplified_line_name, simplified_ink_name);


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
-- Name: reading_statuses fk_rails_17ee7cb2c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reading_statuses
    ADD CONSTRAINT fk_rails_17ee7cb2c4 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: friendships fk_rails_19981bd36e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT fk_rails_19981bd36e FOREIGN KEY (sender_id) REFERENCES public.users(id);


--
-- Name: macro_clusters fk_rails_4b634dc145; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.macro_clusters
    ADD CONSTRAINT fk_rails_4b634dc145 FOREIGN KEY (brand_cluster_id) REFERENCES public.brand_clusters(id);


--
-- Name: collected_inks fk_rails_6e15b56fd1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_inks
    ADD CONSTRAINT fk_rails_6e15b56fd1 FOREIGN KEY (new_ink_name_id) REFERENCES public.new_ink_names(id);


--
-- Name: collected_inks fk_rails_86cd529415; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collected_inks
    ADD CONSTRAINT fk_rails_86cd529415 FOREIGN KEY (micro_cluster_id) REFERENCES public.micro_clusters(id);


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
-- Name: friendships fk_rails_d78dc9c7fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT fk_rails_d78dc9c7fd FOREIGN KEY (friend_id) REFERENCES public.users(id);


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
('20170424062404'),
('20170502055847'),
('20170502060458'),
('20170502061318'),
('20170519062041'),
('20170521181851'),
('20170521185337'),
('20170521190332'),
('20170523152730'),
('20170523152957'),
('20170524055721'),
('20170524060617'),
('20170524060841'),
('20170531055244'),
('20170612134415'),
('20170614061536'),
('20170621145107'),
('20170627114616'),
('20170707150917'),
('20170710185856'),
('20170713111102'),
('20170811073112'),
('20171006061817'),
('20171006062828'),
('20171019061342'),
('20171019062617'),
('20171019155404'),
('20171020060546'),
('20171020061129'),
('20171020061358'),
('20180129071525'),
('20180205070500'),
('20180205071528'),
('20180205072218'),
('20180205161551'),
('20180206073008'),
('20180209065827'),
('20180210084805'),
('20180212105620'),
('20180212111548'),
('20180212114732'),
('20180212131314'),
('20180212144350'),
('20180214072802'),
('20180216175049'),
('20180217122007'),
('20180218142925'),
('20180218190002'),
('20180218193150'),
('20180227181153'),
('20180417144312'),
('20180507062204'),
('20180507063532'),
('20180726060548'),
('20180726060907'),
('20180726061424'),
('20180801054458'),
('20180907143946'),
('20180914060945'),
('20180914062442'),
('20180915175351'),
('20180915181321'),
('20180918051116'),
('20180919200529'),
('20181001104907'),
('20181004061130'),
('20190325074641'),
('20190325084946'),
('20190325092019'),
('20190508191145'),
('20200203072140'),
('20200225125327'),
('20200225141017'),
('20200312201035'),
('20200312201442'),
('20200314133313'),
('20200408173146'),
('20200410182613'),
('20200411105910'),
('20200411110116'),
('20200411110158'),
('20200411110348'),
('20200411111714'),
('20200413140420'),
('20200413140510'),
('20200425193609'),
('20200501083855'),
('20200501084123'),
('20200501084410'),
('20200501084459'),
('20200501112723'),
('20200717152302'),
('20200930122807'),
('20200930124526'),
('20201002133409'),
('20201007070202'),
('20210415062021'),
('20210419191331');


