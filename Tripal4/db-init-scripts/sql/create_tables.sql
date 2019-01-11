--
-- PostgreSQL database dump
--

-- Dumped from database version 10.6 (Ubuntu 10.6-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 10.6 (Ubuntu 10.6-0ubuntu0.18.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: entity; Type: TABLE; Schema: public; Owner: dbadmin
--

CREATE TABLE public.entity (
    entity_id bigint NOT NULL,
    entity_type_id bigint NOT NULL,
    label character varying(2048) NOT NULL,
    provider_id bigint NOT NULL
);


ALTER TABLE public.entity OWNER TO dbadmin;

--
-- Name: COLUMN entity.entity_id; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity.entity_id IS 'The unique internal entity  ID';


--
-- Name: COLUMN entity.entity_type_id; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity.entity_type_id IS 'The foreign key to the entity type';


--
-- Name: COLUMN entity.label; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity.label IS 'The label (title) for this entity';


--
-- Name: COLUMN entity.provider_id; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity.provider_id IS 'The foreign key to the provider.provider_id column.';


--
-- Name: entity_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: dbadmin
--

CREATE SEQUENCE public.entity_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_entity_id_seq OWNER TO dbadmin;

--
-- Name: entity_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbadmin
--

ALTER SEQUENCE public.entity_entity_id_seq OWNED BY public.entity.entity_id;


--
-- Name: entity_field; Type: TABLE; Schema: public; Owner: dbadmin
--

CREATE TABLE public.entity_field (
    entity_field_id bigint NOT NULL,
    entity_id bigint NOT NULL,
    field_id bigint NOT NULL
);


ALTER TABLE public.entity_field OWNER TO dbadmin;

--
-- Name: COLUMN entity_field.entity_field_id; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity_field.entity_field_id IS 'The inique internal ID for mapping a field to an entity.';


--
-- Name: COLUMN entity_field.entity_id; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity_field.entity_id IS 'Foreign key to the entity.entity_id column';


--
-- Name: COLUMN entity_field.field_id; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity_field.field_id IS 'foreign key to the field.field_id column';


--
-- Name: entity_field_entity_field_id_seq; Type: SEQUENCE; Schema: public; Owner: dbadmin
--

CREATE SEQUENCE public.entity_field_entity_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_field_entity_field_id_seq OWNER TO dbadmin;

--
-- Name: entity_field_entity_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbadmin
--

ALTER SEQUENCE public.entity_field_entity_field_id_seq OWNED BY public.entity_field.entity_field_id;


--
-- Name: entity_type; Type: TABLE; Schema: public; Owner: dbadmin
--

CREATE TABLE public.entity_type (
    entity_type_id bigint NOT NULL,
    name character varying(128) NOT NULL,
    term character varying(2048) NOT NULL
);


ALTER TABLE public.entity_type OWNER TO dbadmin;

--
-- Name: COLUMN entity_type.entity_type_id; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity_type.entity_type_id IS 'The unique internal entity type ID';


--
-- Name: COLUMN entity_type.name; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity_type.name IS 'The human readable entity type name';


--
-- Name: COLUMN entity_type.term; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.entity_type.term IS 'The controlled voabulary term (currently this is a string, in the future should be an ID to a term)';


--
-- Name: entity_type_entity_type_id_seq; Type: SEQUENCE; Schema: public; Owner: dbadmin
--

CREATE SEQUENCE public.entity_type_entity_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_type_entity_type_id_seq OWNER TO dbadmin;

--
-- Name: entity_type_entity_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbadmin
--

ALTER SEQUENCE public.entity_type_entity_type_id_seq OWNED BY public.entity_type.entity_type_id;


--
-- Name: field; Type: TABLE; Schema: public; Owner: dbadmin
--

CREATE TABLE public.field (
    field_id bigint NOT NULL,
    name character varying(1024) NOT NULL,
    term character varying(1024) NOT NULL,
    info_array text NOT NULL,
    provider bigint NOT NULL
);


ALTER TABLE public.field OWNER TO dbadmin;

--
-- Name: COLUMN field.field_id; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.field.field_id IS 'The unique internal field  ID';


--
-- Name: COLUMN field.name; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.field.name IS 'The unique machine readable name for the field. Must only contain alphanumeric characters and underscores.';


--
-- Name: COLUMN field.term; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.field.term IS 'The controlled voabulary term (currently this is a string, in the future should be an ID to a term)';


--
-- Name: COLUMN field.info_array; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.field.info_array IS 'A JSON array describing the field.  This is equilvent to the TripalEntity::info() function.';


--
-- Name: COLUMN field.provider; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.field.provider IS 'The foreign key to the provider.provider_id column.';


--
-- Name: field_field_id_seq; Type: SEQUENCE; Schema: public; Owner: dbadmin
--

CREATE SEQUENCE public.field_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.field_field_id_seq OWNER TO dbadmin;

--
-- Name: field_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbadmin
--

ALTER SEQUENCE public.field_field_id_seq OWNED BY public.field.field_id;


--
-- Name: provider; Type: TABLE; Schema: public; Owner: dbadmin
--

CREATE TABLE public.provider (
    provider_id bigint NOT NULL,
    name character varying(1024) NOT NULL,
    label character varying(1024) NOT NULL
);


ALTER TABLE public.provider OWNER TO dbadmin;

--
-- Name: COLUMN provider.provider_id; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.provider.provider_id IS 'The unique internal provider  ID';


--
-- Name: COLUMN provider.name; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.provider.name IS 'The unique machine readable name for the provider. Must only contain alphanumeric characters and underscores.';


--
-- Name: COLUMN provider.label; Type: COMMENT; Schema: public; Owner: dbadmin
--

COMMENT ON COLUMN public.provider.label IS 'The human readable label (title) for the privoder.';


--
-- Name: provider_provider_id_seq; Type: SEQUENCE; Schema: public; Owner: dbadmin
--

CREATE SEQUENCE public.provider_provider_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.provider_provider_id_seq OWNER TO dbadmin;

--
-- Name: provider_provider_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dbadmin
--

ALTER SEQUENCE public.provider_provider_id_seq OWNED BY public.provider.provider_id;


--
-- Name: entity entity_id; Type: DEFAULT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity ALTER COLUMN entity_id SET DEFAULT nextval('public.entity_entity_id_seq'::regclass);


--
-- Name: entity_field entity_field_id; Type: DEFAULT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity_field ALTER COLUMN entity_field_id SET DEFAULT nextval('public.entity_field_entity_field_id_seq'::regclass);


--
-- Name: entity_type entity_type_id; Type: DEFAULT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity_type ALTER COLUMN entity_type_id SET DEFAULT nextval('public.entity_type_entity_type_id_seq'::regclass);


--
-- Name: field field_id; Type: DEFAULT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.field ALTER COLUMN field_id SET DEFAULT nextval('public.field_field_id_seq'::regclass);


--
-- Name: provider provider_id; Type: DEFAULT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.provider ALTER COLUMN provider_id SET DEFAULT nextval('public.provider_provider_id_seq'::regclass);


--
-- Name: entity_field entity_field_pkey; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity_field
    ADD CONSTRAINT entity_field_pkey PRIMARY KEY (entity_field_id);


--
-- Name: entity entity_pkey; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_pkey PRIMARY KEY (entity_id);


--
-- Name: entity_type entity_type_name_key; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity_type
    ADD CONSTRAINT entity_type_name_key UNIQUE (name);


--
-- Name: entity_type entity_type_pkey; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity_type
    ADD CONSTRAINT entity_type_pkey PRIMARY KEY (entity_type_id);


--
-- Name: entity_type entity_type_term_key; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity_type
    ADD CONSTRAINT entity_type_term_key UNIQUE (term);


--
-- Name: field field_name_key; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.field
    ADD CONSTRAINT field_name_key UNIQUE (name);


--
-- Name: field field_pkey; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.field
    ADD CONSTRAINT field_pkey PRIMARY KEY (field_id);


--
-- Name: provider provider_label_key; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.provider
    ADD CONSTRAINT provider_label_key UNIQUE (label);


--
-- Name: provider provider_name_key; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.provider
    ADD CONSTRAINT provider_name_key UNIQUE (name);


--
-- Name: provider provider_pkey; Type: CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.provider
    ADD CONSTRAINT provider_pkey PRIMARY KEY (provider_id);


--
-- Name: entity_entity_type_id_fk1; Type: INDEX; Schema: public; Owner: dbadmin
--

CREATE INDEX entity_entity_type_id_fk1 ON public.entity USING btree (entity_type_id);


--
-- Name: entity_lable_idx; Type: INDEX; Schema: public; Owner: dbadmin
--

CREATE INDEX entity_lable_idx ON public.entity USING btree (label);


--
-- Name: entity_field entity_field_entity_id_fk1; Type: FK CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity_field
    ADD CONSTRAINT entity_field_entity_id_fk1 FOREIGN KEY (entity_id) REFERENCES public.entity(entity_id) ON DELETE CASCADE;


--
-- Name: entity_field entity_field_field_id_fk1; Type: FK CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity_field
    ADD CONSTRAINT entity_field_field_id_fk1 FOREIGN KEY (field_id) REFERENCES public.field(field_id) ON DELETE CASCADE;


--
-- Name: entity entity_provider_id; Type: FK CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_provider_id FOREIGN KEY (provider_id) REFERENCES public.provider(provider_id) ON DELETE CASCADE;


--
-- Name: entity entity_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_type_id_fk FOREIGN KEY (entity_type_id) REFERENCES public.entity_type(entity_type_id) ON DELETE CASCADE;


--
-- Name: field field_provider_id_fk1; Type: FK CONSTRAINT; Schema: public; Owner: dbadmin
--

ALTER TABLE ONLY public.field
    ADD CONSTRAINT field_provider_id_fk1 FOREIGN KEY (provider) REFERENCES public.provider(provider_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--
