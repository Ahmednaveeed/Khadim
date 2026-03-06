--
-- PostgreSQL database dump
--

\restrict SH5fTrq11NUAjp5XxEjZzqsQA5SAhHkf7detA3rOKO6KlsWxxmDmH0AoGGk2zo3

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-03-04 09:23:08

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 7 (class 2615 OID 16689)
-- Name: auth; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA auth;


ALTER SCHEMA auth OWNER TO postgres;

--
-- TOC entry 9 (class 2615 OID 16691)
-- Name: chat; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA chat;


ALTER SCHEMA chat OWNER TO postgres;

--
-- TOC entry 8 (class 2615 OID 16690)
-- Name: orders; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA orders;


ALTER SCHEMA orders OWNER TO postgres;

--
-- TOC entry 2 (class 3079 OID 16614)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 5145 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 279 (class 1255 OID 16729)
-- Name: set_updated_at(); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION auth.set_updated_at() OWNER TO postgres;

--
-- TOC entry 280 (class 1255 OID 16801)
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 238 (class 1259 OID 16692)
-- Name: app_users; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.app_users (
    user_id uuid DEFAULT gen_random_uuid() NOT NULL,
    full_name text NOT NULL,
    email text,
    phone text,
    password_hash text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT app_users_email_or_phone_chk CHECK (((email IS NOT NULL) OR (phone IS NOT NULL)))
);


ALTER TABLE auth.app_users OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 16712)
-- Name: user_preferences; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.user_preferences (
    user_id uuid NOT NULL,
    preferences jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE auth.user_preferences OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16576)
-- Name: cart; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cart (
    cart_id uuid NOT NULL,
    status text DEFAULT 'active'::text,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    user_id uuid
);


ALTER TABLE public.cart OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16599)
-- Name: cart_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cart_items (
    cart_id uuid NOT NULL,
    item_id integer NOT NULL,
    item_type text NOT NULL,
    item_name text,
    quantity integer,
    unit_price numeric(10,2)
);


ALTER TABLE public.cart_items OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16474)
-- Name: chef; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chef (
    cheff_id integer NOT NULL,
    cheff_name text NOT NULL,
    specialty text,
    active_status boolean DEFAULT true,
    max_current_orders integer
);


ALTER TABLE public.chef OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16473)
-- Name: chef_cheff_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.chef_cheff_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.chef_cheff_id_seq OWNER TO postgres;

--
-- TOC entry 5146 (class 0 OID 0)
-- Dependencies: 223
-- Name: chef_cheff_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chef_cheff_id_seq OWNED BY public.chef.cheff_id;


--
-- TOC entry 228 (class 1259 OID 16500)
-- Name: deal; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deal (
    deal_id integer NOT NULL,
    deal_name text NOT NULL,
    deal_price numeric(7,2),
    active boolean DEFAULT true,
    serving_size integer,
    image_url text
);


ALTER TABLE public.deal OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16499)
-- Name: deal_deal_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deal_deal_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.deal_deal_id_seq OWNER TO postgres;

--
-- TOC entry 5147 (class 0 OID 0)
-- Dependencies: 227
-- Name: deal_deal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deal_deal_id_seq OWNED BY public.deal.deal_id;


--
-- TOC entry 229 (class 1259 OID 16511)
-- Name: deal_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deal_item (
    deal_id integer NOT NULL,
    menu_item_id integer NOT NULL,
    quantity integer NOT NULL
);


ALTER TABLE public.deal_item OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16546)
-- Name: kitchen_tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.kitchen_tasks (
    task_id text NOT NULL,
    order_id integer NOT NULL,
    menu_item_id integer,
    item_name text,
    qty integer,
    station text,
    assigned_chef text,
    estimated_minutes integer,
    status text DEFAULT 'QUEUED'::text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.kitchen_tasks OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16486)
-- Name: menu_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.menu_item (
    item_id integer NOT NULL,
    item_name text NOT NULL,
    item_description text,
    item_category text,
    item_cuisine text,
    item_price numeric(7,2),
    item_cost numeric(7,2),
    tags text[],
    availability boolean DEFAULT true,
    serving_size integer,
    quantity_description text,
    prep_time_minutes integer,
    image_url text,
    CONSTRAINT menu_item_item_category_check CHECK ((item_category = ANY (ARRAY['starter'::text, 'main'::text, 'drink'::text, 'side'::text, 'bread'::text]))),
    CONSTRAINT menu_item_item_cuisine_check CHECK ((item_cuisine = ANY (ARRAY['BBQ'::text, 'Desi'::text, 'Fast Food'::text, 'Chinese'::text, 'Drinks'::text])))
);


ALTER TABLE public.menu_item OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16529)
-- Name: menu_item_chefs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.menu_item_chefs (
    menu_item_id integer NOT NULL,
    chef_id integer NOT NULL
);


ALTER TABLE public.menu_item_chefs OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16485)
-- Name: menu_item_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.menu_item_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.menu_item_item_id_seq OWNER TO postgres;

--
-- TOC entry 5148 (class 0 OID 0)
-- Dependencies: 225
-- Name: menu_item_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.menu_item_item_id_seq OWNED BY public.menu_item.item_id;


--
-- TOC entry 233 (class 1259 OID 16562)
-- Name: offers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.offers (
    offer_id integer NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    offer_code text,
    validity date NOT NULL,
    category text NOT NULL,
    CONSTRAINT offers_category_check CHECK ((category = ANY (ARRAY['Fast Food'::text, 'Chinese'::text, 'Desi'::text, 'BBQ'::text, 'Drinks'::text])))
);


ALTER TABLE public.offers OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 16561)
-- Name: offers_offer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.offers_offer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.offers_offer_id_seq OWNER TO postgres;

--
-- TOC entry 5149 (class 0 OID 0)
-- Dependencies: 232
-- Name: offers_offer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.offers_offer_id_seq OWNED BY public.offers.offer_id;


--
-- TOC entry 241 (class 1259 OID 16768)
-- Name: order_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_items (
    id integer NOT NULL,
    order_id integer NOT NULL,
    item_type character varying(16) NOT NULL,
    item_id integer NOT NULL,
    name_snapshot text NOT NULL,
    unit_price_snapshot numeric(12,2) NOT NULL,
    quantity integer NOT NULL,
    line_total numeric(12,2) NOT NULL,
    CONSTRAINT order_items_quantity_check CHECK ((quantity > 0))
);


ALTER TABLE public.order_items OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16767)
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.order_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_items_id_seq OWNER TO postgres;

--
-- TOC entry 5150 (class 0 OID 0)
-- Dependencies: 240
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;


--
-- TOC entry 236 (class 1259 OID 16581)
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orders (
    order_id integer NOT NULL,
    cart_id uuid NOT NULL,
    total_price numeric(10,2) NOT NULL,
    estimated_prep_time_minutes integer,
    order_data jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status text DEFAULT 'confirmed'::text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    delivery_address text,
    subtotal numeric(10,2),
    tax numeric(10,2),
    delivery_fee numeric(10,2)
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16577)
-- Name: orders_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orders_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_order_id_seq OWNER TO postgres;

--
-- TOC entry 5151 (class 0 OID 0)
-- Dependencies: 235
-- Name: orders_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orders_order_id_seq OWNED BY public.orders.order_id;


--
-- TOC entry 4905 (class 2604 OID 16477)
-- Name: chef cheff_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chef ALTER COLUMN cheff_id SET DEFAULT nextval('public.chef_cheff_id_seq'::regclass);


--
-- TOC entry 4909 (class 2604 OID 16503)
-- Name: deal deal_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deal ALTER COLUMN deal_id SET DEFAULT nextval('public.deal_deal_id_seq'::regclass);


--
-- TOC entry 4907 (class 2604 OID 16489)
-- Name: menu_item item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_item ALTER COLUMN item_id SET DEFAULT nextval('public.menu_item_item_id_seq'::regclass);


--
-- TOC entry 4914 (class 2604 OID 16565)
-- Name: offers offer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offers ALTER COLUMN offer_id SET DEFAULT nextval('public.offers_offer_id_seq'::regclass);


--
-- TOC entry 4926 (class 2604 OID 16771)
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);


--
-- TOC entry 4917 (class 2604 OID 16586)
-- Name: orders order_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders ALTER COLUMN order_id SET DEFAULT nextval('public.orders_order_id_seq'::regclass);


--
-- TOC entry 5136 (class 0 OID 16692)
-- Dependencies: 238
-- Data for Name: app_users; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.app_users (user_id, full_name, email, phone, password_hash, is_active, created_at) FROM stdin;
3f008beb-c3ed-4777-9f2a-1c5deb2536e4	Test User	testuser1@gmail.com	\N	$argon2id$v=19$m=65536,t=3,p=4$1hqDkPIeY+y9t7ZWKoXwXg$pW0IZiC8YL2vcCfrZl8DfZ+D2jJ4gj3SUFpoTah6bUQ	t	2026-03-03 23:02:40.343343+05
88572f33-6900-4e9c-ba79-8c1110944802	Sarim	rasheedsarim4@gmail.com	\N	$argon2id$v=19$m=65536,t=3,p=4$mXNuLSWE8D4HoPReS0npPQ$3Y4WiX2lhS6C3vnnz5wHEp1wi51XZ2koqzi4t911tN8	t	2026-03-03 23:14:14.217493+05
\.


--
-- TOC entry 5137 (class 0 OID 16712)
-- Dependencies: 239
-- Data for Name: user_preferences; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.user_preferences (user_id, preferences, updated_at) FROM stdin;
3f008beb-c3ed-4777-9f2a-1c5deb2536e4	{}	2026-03-03 23:02:40.343343+05
88572f33-6900-4e9c-ba79-8c1110944802	{}	2026-03-03 23:14:14.217493+05
\.


--
-- TOC entry 5132 (class 0 OID 16576)
-- Dependencies: 234
-- Data for Name: cart; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cart (cart_id, status, updated_at, user_id) FROM stdin;
5245b12b-49c5-4653-8cce-f16fcf7099b1	inactive	2025-12-10 20:32:07.158497+05	\N
f8370aa7-9df9-4aab-8dd7-2569170bf6f8	inactive	2025-12-10 20:34:20.127949+05	\N
b335e408-5658-4399-8c78-23103577a065	active	2025-12-10 20:35:55.603596+05	\N
0e95b5cc-5283-45d4-825c-42cd70c581d8	active	2025-12-10 20:38:06.901237+05	\N
b246fc8a-a4bf-4a61-8fb6-af586a7108f8	active	2025-12-10 20:43:22.956716+05	\N
b8621145-f269-4fda-80dd-fe2e531d5a1b	inactive	2025-12-13 19:14:36.932501+05	\N
4ded6374-9bb2-41e6-8e1a-8003378bb689	active	2025-12-13 19:20:33.02402+05	\N
24a326d1-91d4-484a-8229-f9fb1e865977	active	2025-12-13 19:24:43.485933+05	\N
cff2ff20-c991-4b22-bf26-7f174575e640	inactive	2025-12-13 19:34:04.845559+05	\N
06f3e718-76ff-4bbd-8580-99046d0555e5	active	2025-12-13 19:38:46.899001+05	\N
eb30509a-3787-4a7a-bf25-c48362de6701	active	2025-12-19 14:48:12.819324+05	\N
304f9d98-26a4-40fa-a66f-a2da2b7beb78	active	2025-12-19 14:48:52.733742+05	\N
33801711-7175-4a3a-88a2-8b0c99cd0623	active	2025-12-26 22:06:42.941526+05	\N
1f2db21d-bfbc-46d6-9df7-2085d7a86bf4	inactive	2025-12-26 22:13:23.798092+05	\N
e53cb4c8-26f6-4cc2-8458-8c1930dd7a1c	active	2025-12-26 22:16:10.819623+05	\N
0bee6f6f-b0aa-464e-833b-903417894dab	active	2025-12-27 01:00:42.363855+05	\N
03c5c3d2-180f-4ca9-8991-c8a1a1025a72	active	2025-12-27 01:05:58.41025+05	\N
94094435-a605-4858-bbc3-b5db707d77b3	active	2025-12-27 01:10:04.039948+05	\N
f358f7c9-1d62-47ee-bdb0-cc54de16e7e4	active	2025-12-27 01:16:56.674437+05	\N
8a4b5bfc-dfbd-45b5-80b9-c8b5d12790fe	active	2025-12-27 01:43:34.726305+05	\N
110a36a0-de25-4bbe-9a46-d5e77696a4ca	active	2025-12-27 01:46:10.940096+05	\N
e850e45a-38cb-4bbe-8465-ebe0d0a86c11	active	2025-12-27 01:53:22.799189+05	\N
edfa0ef4-49cf-4341-a650-1cac4334b6b3	active	2025-12-27 01:56:20.45204+05	\N
5b240ca5-426c-4b55-9e42-b0d7d8a21a1f	active	2025-12-27 02:31:56.513671+05	\N
7cd4e45f-3922-43dc-ad72-175f6f04ff77	active	2025-12-27 02:50:17.122225+05	\N
dc6aa99d-4586-4cb1-83dd-0d9ac2813c85	active	2025-12-27 02:57:09.581271+05	\N
5f3a29c3-9a26-4113-af18-cdddab8269e6	active	2025-12-27 03:12:39.365078+05	\N
1f5c384e-2ca9-4d74-ba79-fa2947c14aaa	active	2025-12-27 03:14:07.476918+05	\N
83852149-71f1-47a0-9196-853dd5497908	active	2025-12-27 03:17:19.126849+05	\N
34b22f8f-b3c3-4f52-a23a-ebea9db3fa8e	active	2025-12-27 03:28:46.358985+05	\N
30f879e1-1f0c-408a-8244-8ed1439c9ef3	active	2025-12-27 03:37:30.524353+05	\N
48f73661-2b78-4edb-b195-b6a83496529f	inactive	2025-12-27 20:33:51.830184+05	\N
6de4d790-8d8f-4a1a-8073-ace513a1afb0	active	2025-12-27 20:50:16.127436+05	\N
dc62cca0-0bfb-4223-947b-4088b95eb97f	active	2026-01-10 12:38:26.122251+05	\N
37e7e473-8625-458d-b7a7-b8fa01dc23a1	active	2026-01-10 12:44:53.248011+05	\N
27761ada-587b-420d-a97d-5283ef32d513	inactive	2026-01-10 13:02:24.996748+05	\N
e9b4d041-48f8-4b73-addf-f76808c53237	active	2026-01-10 13:05:54.806116+05	\N
88572f33-6900-4e9c-ba79-8c1110944802	inactive	2026-03-04 00:03:42.520604+05	88572f33-6900-4e9c-ba79-8c1110944802
\.


--
-- TOC entry 5135 (class 0 OID 16599)
-- Dependencies: 237
-- Data for Name: cart_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cart_items (cart_id, item_id, item_type, item_name, quantity, unit_price) FROM stdin;
4ded6374-9bb2-41e6-8e1a-8003378bb689	981	menu_item	Zinger Burger	2	550.00
8a4b5bfc-dfbd-45b5-80b9-c8b5d12790fe	98	menu_item	Fries	2	200.00
8a4b5bfc-dfbd-45b5-80b9-c8b5d12790fe	842	menu_item	Cola	2	150.00
30f879e1-1f0c-408a-8244-8ed1439c9ef3	782	menu_item	Club Sandwich	1	700.00
\.


--
-- TOC entry 5122 (class 0 OID 16474)
-- Dependencies: 224
-- Data for Name: chef; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chef (cheff_id, cheff_name, specialty, active_status, max_current_orders) FROM stdin;
1	Ali Khan	BBQ	t	4
2	Shah Ali	BBQ	t	4
3	Imran Qureshi	Desi	t	3
4	Fatima Noor	Desi	t	3
5	abdul mateen	Fast Food	t	3
6	akbar ahmed	Fast Food	t	3
7	esha khurram	Chinese	t	2
8	abid Ali	Chinese	t	3
9	Rashid Khan	Breads	t	6
10	Fazal Haq	Drinks	t	5
\.


--
-- TOC entry 5126 (class 0 OID 16500)
-- Dependencies: 228
-- Data for Name: deal; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deal (deal_id, deal_name, deal_price, active, serving_size, image_url) FROM stdin;
5	Fast Food Big Party	5535.00	t	6	assets/images/deals/deal_fastfood.jpeg
1	Fast Solo A	720.00	t	1	assets/images/deals/deal_fastfood.jpeg
2	Fast Solo B	877.50	t	1	assets/images/deals/deal_fastfood.jpeg
3	Fast Duo	1620.00	t	2	assets/images/deals/deal_fastfood.jpeg
4	Fast Squad	3532.50	t	4	assets/images/deals/deal_fastfood.jpeg
6	Chinese Solo	1080.00	t	1	assets/images/deals/deal_chinese.jpeg
7	Chinese Duo	1935.00	t	2	assets/images/deals/deal_chinese.jpeg
8	Chinese Squad A	5670.00	t	4	assets/images/deals/deal_chinese.jpeg
9	Chinese Squad B	4950.00	t	4	assets/images/deals/deal_chinese.jpeg
10	Chinese Party Variety	5850.00	t	6	assets/images/deals/deal_chinese.jpeg
11	BBQ Solo	1350.00	t	1	assets/images/deals/deal_bbq.jpeg
12	BBQ Duo	2187.00	t	2	assets/images/deals/deal_bbq.jpeg
13	BBQ Squad	4725.00	t	4	assets/images/deals/deal_bbq.jpeg
14	BBQ Party A	7758.00	t	6	assets/images/deals/deal_bbq.jpeg
15	BBQ Party B	7641.00	t	6	assets/images/deals/deal_bbq.jpeg
16	Desi Solo	855.00	t	1	assets/images/deals/deal_desi.jpeg
17	Desi Duo	990.00	t	2	assets/images/deals/deal_desi.jpeg
18	Desi Squad A	4590.00	t	4	assets/images/deals/deal_desi.jpeg
19	Desi Squad B	4815.00	t	4	assets/images/deals/deal_desi.jpeg
20	Desi Party	7227.00	t	6	assets/images/deals/deal_desi.jpeg
\.


--
-- TOC entry 5127 (class 0 OID 16511)
-- Dependencies: 229
-- Data for Name: deal_item; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deal_item (deal_id, menu_item_id, quantity) FROM stdin;
1	1	1
1	4	1
1	36	1
2	2	1
2	7	1
2	37	1
3	1	2
3	4	2
3	37	2
4	8	2
4	2	1
4	1	1
4	10	2
4	36	4
5	1	2
5	9	1
5	3	1
5	2	2
5	42	2
5	41	2
5	36	1
5	37	1
5	4	1
5	10	1
5	7	1
5	5	1
6	13	1
6	39	1
7	11	1
7	17	1
7	44	2
8	18	1
8	13	1
8	16	2
8	17	1
8	43	4
9	19	2
9	14	2
9	41	4
10	12	1
10	11	1
10	14	2
10	17	1
10	43	6
11	31	1
11	37	1
11	45	1
12	32	1
12	38	2
12	46	4
13	31	1
13	35	1
13	32	1
13	36	4
13	47	4
14	34	2
14	33	2
14	41	6
14	48	3
14	46	3
15	32	3
15	31	1
15	42	6
15	49	4
15	47	3
16	23	1
16	40	1
16	45	1
17	27	2
17	44	2
17	28	2
18	29	2
18	25	4
18	38	4
19	21	1
19	22	1
19	26	1
19	37	4
20	30	2
20	22	1
20	47	3
20	36	3
20	38	3
20	49	3
\.


--
-- TOC entry 5129 (class 0 OID 16546)
-- Dependencies: 231
-- Data for Name: kitchen_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.kitchen_tasks (task_id, order_id, menu_item_id, item_name, qty, station, assigned_chef, estimated_minutes, status, created_at, updated_at) FROM stdin;
2-1	2	21	Chicken Karahi	2	STOVE	Imran Qureshi	30	READY	2025-12-10 20:35:55.52723+05	2025-12-10 20:37:13.125857+05
5-1	5	44	Water Bottle	2	DRINKS	Fazal Haq	2	QUEUED	2025-12-13 19:38:45.966256+05	2025-12-13 19:38:45.966256+05
5-2	5	47	Garlic Naan	2	TANDOOR	Rashid Khan	3	QUEUED	2025-12-13 19:38:46.298106+05	2025-12-13 19:38:46.298106+05
6-1	6	31	Chicken Tikka	1	GRILL	Ali Khan	20	QUEUED	2025-12-26 22:16:09.847139+05	2025-12-26 22:16:09.847139+05
6-4	6	45	Roti	1	TANDOOR	Rashid Khan	1	QUEUED	2025-12-26 22:16:10.686269+05	2025-12-26 22:16:10.686269+05
3-1	3	9	Zinger Burger	4	FRY	abdul mateen	15	READY	2025-12-13 19:20:32.798432+05	2025-12-27 01:00:58.483+05
7-3	7	3	Veggie Burger	1	FRY	abdul mateen	15	QUEUED	2025-12-27 20:50:13.127555+05	2025-12-27 20:50:13.127555+05
7-4	7	2	Chicken Burger	2	FRY	abdul mateen	15	QUEUED	2025-12-27 20:50:13.359671+05	2025-12-27 20:50:13.359671+05
7-5	7	42	Strawberry Shake	2	DRINKS	Fazal Haq	5	QUEUED	2025-12-27 20:50:13.592759+05	2025-12-27 20:50:13.592759+05
7-6	7	41	Iced Coffee	2	DRINKS	Fazal Haq	5	QUEUED	2025-12-27 20:50:13.856676+05	2025-12-27 20:50:13.856676+05
7-7	7	36	Cola	1	DRINKS	Fazal Haq	2	QUEUED	2025-12-27 20:50:14.092516+05	2025-12-27 20:50:14.092516+05
7-8	7	37	Lemonade	1	DRINKS	Fazal Haq	5	QUEUED	2025-12-27 20:50:14.332262+05	2025-12-27 20:50:14.332262+05
7-9	7	4	Fries	1	FRY	abdul mateen	10	QUEUED	2025-12-27 20:50:14.690967+05	2025-12-27 20:50:14.690967+05
7-10	7	10	Loaded Fries	1	FRY	abdul mateen	10	QUEUED	2025-12-27 20:50:14.976129+05	2025-12-27 20:50:14.976129+05
7-11	7	7	Onion Rings	1	FRY	abdul mateen	10	QUEUED	2025-12-27 20:50:15.296393+05	2025-12-27 20:50:15.296393+05
7-12	7	5	Chicken Nuggets	1	FRY	abdul mateen	10	QUEUED	2025-12-27 20:50:15.72772+05	2025-12-27 20:50:15.72772+05
7-13	7	38	Mint Margarita	1	DRINKS	Fazal Haq	5	QUEUED	2025-12-27 20:50:16.025555+05	2025-12-27 20:50:16.025555+05
7-2	7	9	Zinger Burger	1	FRY	abdul mateen	15	IN_PROGRESS	2025-12-27 20:50:12.886853+05	2025-12-27 20:50:46.588036+05
7-1	7	1	Cheeseburger	2	FRY	abdul mateen	15	READY	2025-12-27 20:50:12.605673+05	2025-12-27 20:50:48.059546+05
\.


--
-- TOC entry 5124 (class 0 OID 16486)
-- Dependencies: 226
-- Data for Name: menu_item; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.menu_item (item_id, item_name, item_description, item_category, item_cuisine, item_price, item_cost, tags, availability, serving_size, quantity_description, prep_time_minutes, image_url) FROM stdin;
12	Sweet and Sour Chicken	Crispy chicken in tangy sauce	main	Chinese	1150.00	690.00	{chicken,sweet,tangy,contains_gluten,halal}	t	3	600g	20	assets/images/menu/chinese/manchurian.jpeg
13	Chicken Chow Mein	Stir-fried noodles with chicken and vegetables	main	Chinese	1000.00	600.00	{chicken,noodles,mild,contains_gluten,contains_soy,halal}	t	2	500g	20	assets/images/menu/chinese/chow_mein.jpeg
14	Vegetable Spring Rolls	Crispy rolls with mixed vegetable filling	starter	Chinese	600.00	360.00	{vegetarian,starter,mild,contains_gluten,vegan}	t	2	6 pieces	10	assets/images/menu/chinese/spring_rolls.jpeg
15	Beef with Black Bean Sauce	Sliced beef in savory black bean sauce	main	Chinese	1350.00	810.00	{beef,sauce,mild,contains_soy,halal}	t	3	600g	20	assets/images/menu/chinese/manchurian.jpeg
16	Egg Fried Rice	Rice stir-fried with egg and vegetables	side	Chinese	800.00	480.00	{vegetarian,rice,mild,contains_eggs,contains_soy}	t	2	300g	10	assets/images/menu/chinese/chow_mein.jpeg
17	Hot and Sour Soup	Spicy, tangy soup with tofu and veggies	starter	Chinese	850.00	510.00	{vegetarian,soup,spicy,tangy,vegan,contains_soy}	t	4	1 bowl of 600ml	15	assets/images/menu/chinese/hot_sour_soup.jpeg
18	Szechuan Beef	Spicy beef with Szechuan peppers	main	Chinese	1450.00	870.00	{beef,very_spicy,contains_soy,halal}	t	3	600g	25	assets/images/menu/chinese/kung_pao.jpeg
19	Chicken Manchurian	Fried chicken balls in spicy sauce	main	Chinese	1250.00	750.00	{chicken,spicy,contains_gluten,contains_soy,halal}	t	3	600g	20	assets/images/menu/chinese/manchurian.jpeg
20	Fish Crackers	Crispy fish-flavored snacks	side	Chinese	500.00	300.00	{fish,snack,mild,contains_gluten}	t	2	12-15 pieces	5	assets/images/menu/chinese/spring_rolls.jpeg
30	Chicken Handi	Creamy chicken curry cooked in a clay pot	main	Desi	2400.00	1440.00	{chicken,curry,creamy,mild_spicy,contains_dairy,halal,goes_with_naan}	t	4	1kg	30	assets/images/menu/desi/chicken_karahi.jpeg
1	Cheeseburger	Classic beef patty with cheese, lettuce, tomato, and sauce	main	Fast Food	450.00	270.00	{beef,burger,mild,contains_dairy,contains_gluten,halal}	t	1	1 burger (200g)	15	assets/images/menu/fast_food/burger.jpeg
2	Chicken Burger	Crispy chicken fillet, mayo, lettuce, and tomato	main	Fast Food	375.00	225.00	{chicken,burger,mild,contains_dairy,contains_gluten,halal}	t	1	1 burger (180g)	15	assets/images/menu/fast_food/chicken_burger.jpeg
3	Veggie Burger	Grilled vegetable patty with cheese and greens	main	Fast Food	300.00	180.00	{vegetarian,burger,mild,contains_dairy,contains_gluten}	t	1	1 burger (170g)	15	assets/images/menu/fast_food/burger.jpeg
4	Fries	Golden fried potato sticks	side	Fast Food	200.00	120.00	{vegetarian,fries,non_spicy,vegan,gluten_free,all_year}	t	1	150g	10	assets/images/menu/fast_food/fries.jpeg
5	Chicken Nuggets	Breaded chicken bites with dip	side	Fast Food	450.00	270.00	{chicken,nuggets,mild,contains_gluten,halal}	t	1	8 pieces (120g)	10	assets/images/menu/fast_food/nuggets.jpeg
6	Fish Fillet Sandwich	Fried fish fillet, tartar sauce, lettuce	main	Fast Food	650.00	390.00	{fish,sandwich,mild,contains_gluten,contains_dairy}	t	1	1 sandwich (250g)	15	assets/images/menu/fast_food/burger.jpeg
7	Onion Rings	Crispy battered onion rings	side	Fast Food	350.00	210.00	{vegetarian,onion,mild,contains_gluten}	t	1	8 rings (120g)	10	assets/images/menu/fast_food/fries.jpeg
8	Club Sandwich	Triple-layered sandwich with chicken, egg, and veggies	main	Fast Food	700.00	420.00	{chicken,sandwich,mild,contains_eggs,contains_gluten,contains_dairy}	t	1	4 pieces (300g)	15	assets/images/menu/fast_food/burger.jpeg
9	Zinger Burger	Spicy fried chicken fillet, lettuce, and mayo	main	Fast Food	550.00	330.00	{chicken,spicy,burger,contains_dairy,contains_gluten,halal}	t	1	1 burger (200g)	15	assets/images/menu/fast_food/chicken_burger.jpeg
10	Loaded Fries	Fries topped with cheese, jalapenos, chicken, and sauce	side	Fast Food	550.00	330.00	{vegetarian,fries,chicken,cheese,mild_spicy,contains_dairy}	t	1	200g	10	assets/images/menu/fast_food/loaded_fries.jpeg
31	Chicken Tikka	Marinated chicken pieces grilled on skewers	main	BBQ	1200.00	720.00	{chicken,grilled,bbq,spicy,contains_dairy,halal,gluten_free}	t	2	1 leg and 1 chest piece	20	https://yourcdn.com/menu/bbq.jpg
32	Beef Boti	Cubes of beef marinated and grilled	main	BBQ	1450.00	870.00	{beef,grilled,bbq,spicy,contains_dairy,halal,gluten_free}	t	4	12 pieces	25	https://yourcdn.com/menu/bbq.jpg
33	Malai Boti	Creamy, tender chicken cubes grilled	main	BBQ	1400.00	840.00	{chicken,creamy,grilled,bbq,mild,contains_dairy,halal,gluten_free}	t	4	12 pieces	20	https://yourcdn.com/menu/bbq.jpg
34	Reshmi Kebab	Soft, silky chicken kebabs	main	BBQ	1350.00	810.00	{chicken,kebab,bbq,mild,contains_dairy,halal,gluten_free}	t	4	8 pieces	25	https://yourcdn.com/menu/bbq.jpg
35	Grilled Fish	Spiced fish fillet grilled over charcoal	main	BBQ	1600.00	960.00	{fish,grilled,bbq,spicy,gluten_free,seasonal_summer}	t	4	800g	20	https://yourcdn.com/menu/bbq.jpg
11	Kung Pao Chicken	Stir-fried chicken with peanuts and chili	main	Chinese	1200.00	720.00	{chicken,spicy,contains_nuts,contains_soy,halal}	t	3	600g	20	assets/images/menu/chinese/kung_pao.jpeg
21	Chicken Karahi	Spicy chicken curry with tomatoes and green chilies	main	Desi	2250.00	1350.00	{chicken,spicy,curry,contains_dairy,halal,goes_with_naan}	t	4	1kg	30	assets/images/menu/desi/chicken_karahi.jpeg
22	Beef Biryani	Aromatic rice with beef and spices	main	Desi	1250.00	750.00	{beef,rice,mild_spicy,contains_dairy,halal}	t	3	1 plate (500g)	15	assets/images/menu/desi/biryani.jpeg
23	Daal Chawal	Lentil curry served with rice	main	Desi	650.00	390.00	{vegetarian,lentil,rice,mild,vegan,gluten_free}	t	2	1 plate (350g)	10	assets/images/menu/desi/daal_chawal.jpeg
24	Nihari	Slow-cooked beef stew	main	Desi	1350.00	810.00	{beef,stew,mild_spicy,halal,goes_with_naan}	t	4	500g	25	assets/images/menu/desi/nihari.jpeg
25	Aloo Paratha	Flatbread stuffed with spiced potatoes	bread	Desi	250.00	150.00	{vegetarian,bread,mild,contains_gluten,contains_dairy}	t	1	1 piece	10	assets/images/menu/desi/paratha.jpeg
26	Palak Paneer	Spinach curry with cottage cheese	main	Desi	850.00	510.00	{vegetarian,cheese,curry,mild,contains_dairy,goes_with_naan}	t	3	1 plate (600g)	20	assets/images/menu/desi/chicken_karahi.jpeg
27	Chana Chaat	Spicy chickpea salad	starter	Desi	150.00	90.00	{vegetarian,chickpea,salad,tangy,spicy,vegan,gluten_free}	t	1	200g	5	assets/images/menu/desi/chana_chaat.jpeg
28	Samosa Platter	Fried pastry with potato and pea filling	starter	Desi	250.00	150.00	{vegetarian,starter,pastry,mild_spicy,contains_gluten,vegan}	t	1	2 samosa pieces	5	assets/images/menu/desi/samosa.jpeg
29	Seekh Kabab	Minced meat skewers grilled to perfection	main	Desi	1350.00	810.00	{meat,kebab,spicy,halal,gluten_free}	t	4	8 kababs	25	assets/images/menu/desi/nihari.jpeg
45	Roti	Traditional whole wheat flatbread, soft and fresh	bread	Desi	50.00	30.00	{bread,wheat,mild,vegan,all_year}	t	1	1 piece	1	assets/images/menu/bread/roti.jpeg
46	Naan	Soft, leavened white flour bread, baked in a tandoor	bread	Desi	70.00	42.00	{bread,white_flour,mild,contains_dairy,vegetarian,all_year}	t	1	1 piece	1	assets/images/menu/bread/naan.jpeg
47	Garlic Naan	Naan topped with garlic and herbs	bread	Desi	100.00	60.00	{bread,garlic,mild,contains_dairy,vegetarian,all_year}	t	1	1 piece	3	assets/images/menu/bread/garlic_naan.jpeg
48	Paratha	Flaky, layered flatbread, pan-fried with ghee	bread	Desi	70.00	42.00	{bread,ghee,mild,contains_dairy,vegetarian,all_year}	t	1	1 piece	3	assets/images/menu/bread/paratha.jpeg
49	Chapatti	Thin, soft whole wheat flatbread	bread	Desi	60.00	36.00	{bread,wheat,mild,vegan,all_year}	t	1	1 piece	1	assets/images/menu/bread/roti.jpeg
36	Cola	Chilled carbonated soft drink	drink	Drinks	150.00	90.00	{cold,soft_drink,non_spicy,vegan,gluten_free,all_year}	t	1	330 ml	2	assets/images/menu/drinks/cola.jpeg
37	Lemonade	Freshly squeezed lemon juice with sugar	drink	Drinks	250.00	150.00	{cold,lemon,tangy,vegan,gluten_free,seasonal_summer}	t	1	400 ml	5	assets/images/menu/drinks/lemonade.jpeg
38	Mint Margarita	Refreshing mint and lemon mocktail	drink	Drinks	350.00	210.00	{cold,mint,mocktail,refreshing,vegan,gluten_free,seasonal_summer}	t	1	350 ml	5	assets/images/menu/drinks/mint_margarita.jpeg
39	Green Tea	Hot brewed green tea	drink	Drinks	200.00	120.00	{hot,tea,mild,vegan,gluten_free,all_year}	t	1	250 ml	5	assets/images/menu/drinks/chai.jpeg
40	Chai	Milk tea, a South Asian favorite	drink	Drinks	250.00	150.00	{hot,tea,milk,sweet,contains_dairy,all_year}	t	1	250 ml	5	assets/images/menu/drinks/chai.jpeg
41	Iced Coffee	Chilled coffee with milk and ice	drink	Drinks	450.00	270.00	{cold,coffee,milk,contains_dairy,all_year}	t	1	350 ml	5	assets/images/menu/drinks/iced_coffee.jpeg
42	Strawberry Shake	Creamy milkshake with fresh strawberries	drink	Drinks	400.00	240.00	{cold,shake,strawberry,sweet,contains_dairy,seasonal_summer}	t	1	350 ml	5	assets/images/menu/drinks/lemonade.jpeg
43	Orange Juice	Freshly squeezed orange juice	drink	Drinks	350.00	210.00	{cold,juice,orange,sweet,vegan,gluten_free,seasonal_winter}	t	1	300 ml	5	assets/images/menu/drinks/lemonade.jpeg
44	Water Bottle	Chilled mineral water	drink	Drinks	150.00	90.00	{cold,water,non_spicy,vegan,gluten_free,all_year}	t	1	500 ml	2	assets/images/menu/drinks/cola.jpeg
\.


--
-- TOC entry 5128 (class 0 OID 16529)
-- Dependencies: 230
-- Data for Name: menu_item_chefs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.menu_item_chefs (menu_item_id, chef_id) FROM stdin;
31	1
32	1
33	1
34	1
35	1
31	2
32	2
33	2
34	2
35	2
21	3
22	3
23	3
24	3
26	3
27	3
28	3
29	3
30	3
21	4
22	4
23	4
24	4
26	4
27	4
28	4
29	4
30	4
1	5
2	5
3	5
4	5
5	5
6	5
7	5
8	5
9	5
10	5
1	6
2	6
3	6
4	6
5	6
6	6
7	6
8	6
9	6
10	6
11	7
12	7
13	7
14	7
15	7
16	7
17	7
18	7
19	7
20	7
11	8
12	8
13	8
14	8
15	8
16	8
17	8
18	8
19	8
20	8
25	9
45	9
46	9
47	9
48	9
49	9
36	10
37	10
38	10
39	10
40	10
41	10
42	10
43	10
44	10
\.


--
-- TOC entry 5131 (class 0 OID 16562)
-- Dependencies: 233
-- Data for Name: offers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.offers (offer_id, title, description, offer_code, validity, category) FROM stdin;
1	Weekend Special Combo	Buy 1 large pizza, get 1 small free!	WEEKEND50	2025-12-15	Fast Food
2	Burger Bonanza	Flat 25% off on all burger meals.	BURGER25	2025-12-17	Fast Food
3	Family Feast Offer	Free dessert on orders above Rs 5000.	FAMILYFEAST	2025-12-20	Desi
\.


--
-- TOC entry 5139 (class 0 OID 16768)
-- Dependencies: 241
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_items (id, order_id, item_type, item_id, name_snapshot, unit_price_snapshot, quantity, line_total) FROM stdin;
3	10	deal	1	Fast Solo A	720.00	1	720.00
4	10	deal	4	Fast Squad	3532.50	1	3532.50
\.


--
-- TOC entry 5134 (class 0 OID 16581)
-- Dependencies: 236
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (order_id, cart_id, total_price, estimated_prep_time_minutes, order_data, created_at, status, updated_at, delivery_address, subtotal, tax, delivery_fee) FROM stdin;
1	5245b12b-49c5-4653-8cce-f16fcf7099b1	550.00	15	{"items": [{"item_id": 60, "quantity": 1, "item_name": "Zinger Burger", "item_type": "menu_item", "unit_price": 550.0, "total_price": 550.0}], "success": true, "is_empty": false, "total_price": 550.0}	2025-12-10 20:34:19.306683+05	confirmed	2026-03-01 02:10:50.56981+05	\N	\N	\N	\N
2	f8370aa7-9df9-4aab-8dd7-2569170bf6f8	4500.00	15	{"items": [{"item_id": 183, "quantity": 2, "item_name": "Chicken Karahi", "item_type": "menu_item", "unit_price": 2250.0, "total_price": 4500.0}], "success": true, "is_empty": false, "total_price": 4500.0}	2025-12-10 20:35:55.180475+05	confirmed	2026-03-01 02:10:50.56981+05	\N	\N	\N	\N
3	b8621145-f269-4fda-80dd-fe2e531d5a1b	2200.00	15	{"items": [{"item_id": 981, "quantity": 4, "item_name": "Zinger Burger", "item_type": "menu_item", "unit_price": 550.0, "total_price": 2200.0}], "success": true, "is_empty": false, "total_price": 2200.0}	2025-12-13 19:20:31.814299+05	confirmed	2026-03-01 02:10:50.56981+05	\N	\N	\N	\N
4	cff2ff20-c991-4b22-bf26-7f174575e640	500.00	3	{"items": [{"item_id": 44, "quantity": 2, "item_name": "Water Bottle", "item_type": "menu_item", "unit_price": 150.0, "total_price": 300.0}, {"item_id": 47, "quantity": 2, "item_name": "Garlic Naan", "item_type": "menu_item", "unit_price": 100.0, "total_price": 200.0}], "success": true, "is_empty": false, "total_price": 500.0}	2025-12-13 19:38:45.130603+05	confirmed	2026-03-01 02:10:50.56981+05	\N	\N	\N	\N
5	cff2ff20-c991-4b22-bf26-7f174575e640	500.00	3	{"items": [{"item_id": 44, "quantity": 2, "item_name": "Water Bottle", "item_type": "menu_item", "unit_price": 150.0, "total_price": 300.0}, {"item_id": 47, "quantity": 2, "item_name": "Garlic Naan", "item_type": "menu_item", "unit_price": 100.0, "total_price": 200.0}], "success": true, "is_empty": false, "total_price": 500.0}	2025-12-13 19:38:45.13005+05	confirmed	2026-03-01 02:10:50.56981+05	\N	\N	\N	\N
6	1f2db21d-bfbc-46d6-9df7-2085d7a86bf4	2550.00	15	{"items": [{"item_id": 813, "quantity": 1, "item_name": "Chicken Tikka", "item_type": "menu_item", "unit_price": 1200.0, "total_price": 1200.0}, {"item_id": 497, "quantity": 1, "item_name": "BBQ Solo", "item_type": "deal", "unit_price": 1350.0, "total_price": 1350.0}], "success": true, "is_empty": false, "total_price": 2550.0}	2025-12-26 22:16:08.554298+05	confirmed	2026-03-01 02:10:50.56981+05	\N	\N	\N	\N
7	48f73661-2b78-4edb-b195-b6a83496529f	5885.00	15	{"items": [{"item_id": 918, "quantity": 1, "item_name": "Fast Food Big Party", "item_type": "deal", "unit_price": 5535.0, "total_price": 5535.0}, {"item_id": 283, "quantity": 1, "item_name": "Mint Margarita", "item_type": "menu_item", "unit_price": 350.0, "total_price": 350.0}], "success": true, "is_empty": false, "total_price": 5885.0}	2025-12-27 20:50:11.862095+05	confirmed	2026-03-01 02:10:50.56981+05	\N	\N	\N	\N
8	27761ada-587b-420d-a97d-5283ef32d513	550.00	15	{"items": [{"item_id": 122, "quantity": 1, "item_name": "Zinger Burger", "item_type": "menu_item", "unit_price": 550.0, "total_price": 550.0}], "success": true, "is_empty": false, "total_price": 550.0}	2026-01-10 13:05:53.179439+05	confirmed	2026-03-01 02:10:50.56981+05	\N	\N	\N	\N
9	88572f33-6900-4e9c-ba79-8c1110944802	4252.50	15	{"items": [{"item_id": 1, "quantity": 1, "item_name": "Fast Solo A", "item_type": "deal", "unit_price": 720.0, "total_price": 720.0}, {"item_id": 4, "quantity": 1, "item_name": "Fast Squad", "item_type": "deal", "unit_price": 3532.5, "total_price": 3532.5}], "success": true, "is_empty": false, "total_price": 4252.5}	2026-03-03 23:35:37.993987+05	confirmed	2026-03-03 23:35:37.993987+05	\N	\N	\N	\N
10	88572f33-6900-4e9c-ba79-8c1110944802	4252.50	15	{"items": [{"item_id": 1, "quantity": 1, "item_name": "Fast Solo A", "item_type": "deal", "unit_price": 720.0, "total_price": 720.0}, {"item_id": 4, "quantity": 1, "item_name": "Fast Squad", "item_type": "deal", "unit_price": 3532.5, "total_price": 3532.5}], "success": true, "is_empty": false, "total_price": 4252.5}	2026-03-04 00:03:54.749355+05	confirmed	2026-03-04 00:03:54.749355+05	\N	\N	\N	\N
\.


--
-- TOC entry 5152 (class 0 OID 0)
-- Dependencies: 223
-- Name: chef_cheff_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chef_cheff_id_seq', 10, true);


--
-- TOC entry 5153 (class 0 OID 0)
-- Dependencies: 227
-- Name: deal_deal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.deal_deal_id_seq', 20, true);


--
-- TOC entry 5154 (class 0 OID 0)
-- Dependencies: 225
-- Name: menu_item_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.menu_item_item_id_seq', 49, true);


--
-- TOC entry 5155 (class 0 OID 0)
-- Dependencies: 232
-- Name: offers_offer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.offers_offer_id_seq', 3, true);


--
-- TOC entry 5156 (class 0 OID 0)
-- Dependencies: 240
-- Name: order_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.order_items_id_seq', 4, true);


--
-- TOC entry 5157 (class 0 OID 0)
-- Dependencies: 235
-- Name: orders_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orders_order_id_seq', 10, true);


--
-- TOC entry 4954 (class 2606 OID 16709)
-- Name: app_users app_users_email_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.app_users
    ADD CONSTRAINT app_users_email_key UNIQUE (email);


--
-- TOC entry 4956 (class 2606 OID 16711)
-- Name: app_users app_users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.app_users
    ADD CONSTRAINT app_users_phone_key UNIQUE (phone);


--
-- TOC entry 4958 (class 2606 OID 16707)
-- Name: app_users app_users_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.app_users
    ADD CONSTRAINT app_users_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4960 (class 2606 OID 16723)
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4952 (class 2606 OID 16608)
-- Name: cart_items cart_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart_items
    ADD CONSTRAINT cart_items_pkey PRIMARY KEY (cart_id, item_id, item_type);


--
-- TOC entry 4947 (class 2606 OID 16598)
-- Name: cart cart_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_pkey PRIMARY KEY (cart_id);


--
-- TOC entry 4933 (class 2606 OID 16484)
-- Name: chef chef_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chef
    ADD CONSTRAINT chef_pkey PRIMARY KEY (cheff_id);


--
-- TOC entry 4939 (class 2606 OID 16518)
-- Name: deal_item deal_item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deal_item
    ADD CONSTRAINT deal_item_pkey PRIMARY KEY (deal_id, menu_item_id);


--
-- TOC entry 4937 (class 2606 OID 16510)
-- Name: deal deal_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_pkey PRIMARY KEY (deal_id);


--
-- TOC entry 4943 (class 2606 OID 16557)
-- Name: kitchen_tasks kitchen_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kitchen_tasks
    ADD CONSTRAINT kitchen_tasks_pkey PRIMARY KEY (task_id);


--
-- TOC entry 4941 (class 2606 OID 16535)
-- Name: menu_item_chefs menu_item_chefs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_item_chefs
    ADD CONSTRAINT menu_item_chefs_pkey PRIMARY KEY (menu_item_id, chef_id);


--
-- TOC entry 4935 (class 2606 OID 16498)
-- Name: menu_item menu_item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_item
    ADD CONSTRAINT menu_item_pkey PRIMARY KEY (item_id);


--
-- TOC entry 4945 (class 2606 OID 16575)
-- Name: offers offers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_pkey PRIMARY KEY (offer_id);


--
-- TOC entry 4963 (class 2606 OID 16784)
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- TOC entry 4950 (class 2606 OID 16597)
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- TOC entry 4961 (class 1259 OID 16790)
-- Name: idx_order_items_order_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_order_items_order_id ON public.order_items USING btree (order_id);


--
-- TOC entry 4948 (class 1259 OID 16796)
-- Name: unique_active_cart_per_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_active_cart_per_user ON public.cart USING btree (user_id) WHERE (status = 'active'::text);


--
-- TOC entry 4973 (class 2620 OID 16730)
-- Name: user_preferences trg_user_preferences_updated; Type: TRIGGER; Schema: auth; Owner: postgres
--

CREATE TRIGGER trg_user_preferences_updated BEFORE UPDATE ON auth.user_preferences FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();


--
-- TOC entry 4972 (class 2620 OID 16802)
-- Name: orders trg_orders_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 4970 (class 2606 OID 16724)
-- Name: user_preferences user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.user_preferences
    ADD CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.app_users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4969 (class 2606 OID 16609)
-- Name: cart_items cart_items_cart_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart_items
    ADD CONSTRAINT cart_items_cart_id_fkey FOREIGN KEY (cart_id) REFERENCES public.cart(cart_id) ON DELETE CASCADE;


--
-- TOC entry 4968 (class 2606 OID 16791)
-- Name: cart cart_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_user_fk FOREIGN KEY (user_id) REFERENCES auth.app_users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4964 (class 2606 OID 16519)
-- Name: deal_item deal_item_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deal_item
    ADD CONSTRAINT deal_item_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(deal_id) ON DELETE CASCADE;


--
-- TOC entry 4965 (class 2606 OID 16524)
-- Name: deal_item deal_item_menu_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deal_item
    ADD CONSTRAINT deal_item_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_item(item_id);


--
-- TOC entry 4966 (class 2606 OID 16541)
-- Name: menu_item_chefs menu_item_chefs_chef_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_item_chefs
    ADD CONSTRAINT menu_item_chefs_chef_id_fkey FOREIGN KEY (chef_id) REFERENCES public.chef(cheff_id);


--
-- TOC entry 4967 (class 2606 OID 16536)
-- Name: menu_item_chefs menu_item_chefs_menu_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_item_chefs
    ADD CONSTRAINT menu_item_chefs_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_item(item_id);


--
-- TOC entry 4971 (class 2606 OID 16785)
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


-- Completed on 2026-03-04 09:23:09

--
-- PostgreSQL database dump complete
--

\unrestrict SH5fTrq11NUAjp5XxEjZzqsQA5SAhHkf7detA3rOKO6KlsWxxmDmH0AoGGk2zo3

