begin;

-- Schemas
create schema if not exists public;
create schema if not exists pythia_public;
create schema if not exists pythia_private;


-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists "citext";


-- Types
create type pythia_public.account_type as enum (
  'asset',
  'equity',
  'expense',
  'liability',
  'revenue',
  'contra'
);

comment on type pythia_public.account_type is 'The possible types of accounts';


-- Global table Functions
create function pythia_private.set_updated_at() returns trigger as $$
begin
  new.updated_at := current_timestamp;
  return new;
end;
$$ language plpgsql;


create function pythia_public.graphql_subscription() returns trigger as $$
declare
  v_process_new bool = (TG_OP = 'INSERT' OR TG_OP = 'UPDATE');
  v_process_old bool = (TG_OP = 'UPDATE' OR TG_OP = 'DELETE');
  v_event text = TG_ARGV[0];
  v_topic_template text = TG_ARGV[1];
  v_attribute text = TG_ARGV[2];
  v_record record;
  v_sub text;
  v_topic text;
  v_i int = 0;
  v_last_topic text;
begin
  for v_i in 0..1 loop
    if (v_i = 0) and v_process_new is true then
      v_record = new;
    elsif (v_i = 1) and v_process_old is true then
      v_record = old;
    else
      continue;
    end if;
     if v_attribute is not null then
      execute 'select $1.' || quote_ident(v_attribute)
        using v_record
        into v_sub;
    end if;
    if v_sub is not null then
      v_topic = replace(v_topic_template, '$1', v_sub);
    else
      v_topic = v_topic_template;
    end if;
    if v_topic is distinct from v_last_topic then
      -- This if statement prevents us from triggering the same notification twice
      v_last_topic = v_topic;
      perform pg_notify(v_topic, json_build_object(
        'event', v_event,
        'subject', v_sub
      )::text);
    end if;
  end loop;
  return v_record;
end;
$$ language plpgsql volatile set search_path from current;


-- Core Ledger Acounting
create table pythia_public.accounts (
  id               uuid primary key default uuid_generate_v4(),
  created_at       timestamp default now(),
  updated_at       timestamp default now(),
  type             pythia_public.account_type not null,
  name             text not null check (char_length(name) < 255),
  code             text check (char_length(name) < 255),
  metadata         jsonb
);

create unique index on pythia_public.accounts (code);

create trigger account_updated_at before update
  on pythia_public.accounts
  for each row
  execute procedure pythia_private.set_updated_at();

comment on table pythia_public.accounts is E'@omit delete\nAn account to which every posting belongs.';
comment on column pythia_public.accounts.id is E'@omit create,update\nThe primary unique identifier for the account.';
comment on column pythia_public.accounts.created_at is E'@omit create,update\nThe account’s time created.';
comment on column pythia_public.accounts.updated_at is E'@omit create,update\nThe account’s last updated time.';
comment on column pythia_public.accounts.type is 'The account’s type.';
comment on column pythia_public.accounts.name is 'The account’s name.';
comment on column pythia_public.accounts.code is 'An alphanumeric account code to identify the account.';
comment on column pythia_public.accounts.metadata is 'A dictionary of arbitrary key-values.';

-- @comment not clear this is necessary, could be an ISO standard of currencies as enum,
-- however, if it's a table you can dynamically use this to store /any/ possible types
-- of denominations for accounts - including other asset categories
-- @comment these should be ISO 4217 probably
create table pythia_public.commodities (
  id               uuid primary key default uuid_generate_v4(),
  created_at       timestamp default now(),
  updated_at       timestamp default now(),
  name             text not null check (char_length(name) < 255),
  code             text not null check (char_length(code) <= 3)
);

create unique index on pythia_public.commodities (code);

create trigger commodity_updated_at before update
  on pythia_public.commodities
  for each row
  execute procedure pythia_private.set_updated_at();

comment on table pythia_public.commodities is E'@omit delete\nA type of asset (commodity) that postings are denominated in.';
comment on column pythia_public.commodities.id is E'@omit create,update\nThe primary unique identifier for the commodity.';
comment on column pythia_public.commodities.created_at is E'@omit create,update\nThe commodity’s time created.';
comment on column pythia_public.commodities.updated_at is E'@omit create,update\nThe commodity’s last updated time.';
comment on column pythia_public.commodities.name is 'A common name/label for the commodity.';
comment on column pythia_public.commodities.code is 'An ISO 4217 code';


create table pythia_public.postings (
  id                uuid primary key default uuid_generate_v4(),
  credit_id         uuid not null references pythia_public.accounts(id) on delete restrict,
  debit_id          uuid not null references pythia_public.accounts(id) on delete restrict,
  commodity_id      uuid not null references pythia_public.commodities(id) on delete restrict,
  created_at        timestamp default now(),
  amount            bigint not null check(amount <= 9007199254740991 AND amount >= 0), -- @note to support JavaScripts 2^53 - 1 maximum value
  external_id       text not null,
  metadata          jsonb
);

create unique index on pythia_public.postings (external_id);
create index on pythia_public.postings (amount);
create index on pythia_public.postings (credit_id);
create index on pythia_public.postings (debit_id);
create index on pythia_public.postings (commodity_id);
create index on pythia_public.postings (created_at);

CREATE TRIGGER posting_created
  AFTER INSERT ON pythia_public.postings
  FOR EACH ROW
  EXECUTE PROCEDURE pythia_public.graphql_subscription(
    'postingCreated',     -- the "event" string, useful for the client to know what happened
    'graphql:posting:$1', -- the "topic" the event will be published to, as a template
    'id'                  -- If specified, `$1` above will be replaced with NEW.id or OLD.id from the trigger.
  );


-- @TODO create a role that allows only inserts
-- @comment postings cannot be mutated
-- grant select, insert on table pythia_public.postings to signed_in;

-- alter table pythia_public.postings enable row level security;

-- @comment always allow the insertion
-- create policy insert_postings on pythia_public.postings for insert with check (true);
-- create policy select_postings on pythia_public.postings for select
--   using (user_id = pythia_public.current_user_id());

comment on table pythia_public.postings is E'@omit update,delete\nA record of a credit/debt (amount) on an account.';
comment on column pythia_public.postings.id is E'@omit create,update\nThe primary unique identifier for the posting.';
comment on column pythia_public.postings.credit_id is 'The account to which the amount is credited.';
comment on column pythia_public.postings.debit_id is 'The account to which the amount is debited.';
comment on column pythia_public.postings.commodity_id is 'The kind of asset class the amount is denominated in.';
comment on column pythia_public.postings.created_at is E'@omit create\nThe posting’s time created.';
comment on column pythia_public.postings.amount is 'The amount (credit/debit) applied in the transaction.';
comment on column pythia_public.postings.metadata is 'A dictionary of arbitrary key-values.';

-- VIEWs

create view pythia_public.ledger as
select account_ledger.*, accounts.name as "account_name", commodities.name as "commodity_name", commodities.code as "commodity_code" from (
  select sum(account_balances.balance) as "balance", account_balances.account_id, account_balances.commodity_id from (
    select
      sum(postings.amount) as "balance",
      postings.credit_id as "account_id",
      postings.commodity_id
    from pythia_public.postings
    group by postings.credit_id, postings.commodity_id
    union
    select
      sum(postings.amount * -1) as "balance",
      postings.debit_id as "account_id",
      postings.commodity_id
    from pythia_public.postings
    group by postings.debit_id, postings.commodity_id
  ) as account_balances
  group by account_balances.account_id, account_balances.commodity_id
) as account_ledger
left join pythia_public.commodities ON account_ledger.commodity_id = commodities.id
left join pythia_public.accounts on account_ledger.account_id = accounts.id;

comment on view pythia_public.ledger is 'A global ledger view of all accounts';


commit;