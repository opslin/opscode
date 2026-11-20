-- Target Postgres schema for the lead store (docs/lead-intelligence-design.md §5).
-- The local store (store.ts) keeps the same collections as JSONL files; a Postgres adapter would use these tables.
-- Evidence rules that the local store enforces in code are marked "rule:" so the adapter keeps them as constraints or triggers.

create table organizations (
  id uuid primary key, name text not null, domains text[] not null default '{}', hq_country char(2), size_band text,
  industry_codes text[], definition text, description_short text, founded int, created_at timestamptz not null, updated_at timestamptz not null
);
create index on organizations using gin (domains);
create table locations (id uuid primary key, org_id uuid not null references organizations on delete cascade, city text, country char(2), address text, phone text, opened_at date);
create table persons (id uuid primary key, name text not null, country char(2), created_at timestamptz not null);
create table roles (
  id uuid primary key, person_id uuid not null references persons on delete cascade, org_id uuid not null references organizations on delete cascade,
  title_raw text not null, seniority text not null, buyer_power text not null check (buyer_power in ('decides','influences','user')), start_date date, end_date date
);
create table accounts (
  id uuid primary key, person_id uuid references persons on delete cascade, org_id uuid references organizations on delete cascade,
  platform text not null, handle text not null, url text,
  link_proof text not null check (length(trim(link_proof)) > 0),            -- rule: no account without proof it belongs to them
  check (person_id is not null or org_id is not null)
);
create table documents (
  id uuid primary key, platform text not null, url text not null, text text not null, hash text not null, published_at timestamptz,
  fetched_at timestamptz not null, author_account_id uuid references accounts on delete cascade, language text, unique (url, hash)
);
create table observations (
  id uuid primary key, subject_type text not null check (subject_type in ('organization','person')), subject_id uuid not null,
  predicate text not null, object text not null,
  evidence_quote text not null check (length(trim(evidence_quote)) > 0),     -- rule: no fact without a quote
  url text not null, document_id uuid references documents on delete cascade, seen_at timestamptz not null,
  valid_from timestamptz, valid_to timestamptz, confidence real not null check (confidence between 0 and 1), extractor text not null
  -- rule: when document_id is set, evidence_quote must occur in documents.text (whitespace/case-insensitive)
);
create index on observations (subject_type, subject_id);
create table signals (id uuid primary key, org_id uuid not null references organizations on delete cascade, type text not null, date timestamptz not null, strength real not null check (strength between 0 and 1));
create table signal_observations (signal_id uuid references signals on delete cascade, observation_id uuid references observations on delete cascade, primary key (signal_id, observation_id));
  -- rule: a signal has at least one observation, all about the signal's organization
create table needs (id uuid primary key, org_id uuid not null references organizations on delete cascade, need_type text not null, description text not null, status text not null check (status in ('open','in_progress','solved')), first_seen timestamptz not null, last_seen timestamptz not null, unique (org_id, need_type));
create table need_signals (need_id uuid references needs on delete cascade, signal_id uuid references signals on delete cascade, primary key (need_id, signal_id));
create table interests (id uuid primary key, subject_id uuid not null, topic text not null, stance text not null, last_seen timestamptz not null);
create table leads (id uuid primary key, person_id uuid not null references persons on delete cascade, org_id uuid not null references organizations on delete cascade, need_id uuid not null references needs, offering_id uuid not null, scores jsonb not null, reasons text[] not null, rubric jsonb, created_at timestamptz not null);
create table interactions (id uuid primary key, lead_id uuid not null references leads on delete cascade, channel text not null, direction text not null, intent text, text text not null, at timestamptz not null);
create table suppressions (id uuid primary key, kind text not null check (kind in ('email','domain','person')), value text not null, reason text not null, created_at timestamptz not null, unique (kind, value));  -- rule: suppressed values can never be added
create table offerings (id uuid primary key, name text not null, summary text not null, solves text[] not null, proof text[] not null, pricing_rules text not null, never_say text[] not null, links text[] not null);
