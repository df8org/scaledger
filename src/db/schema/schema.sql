begin;

-- Schemas
create schema if not exists public;
create schema if not exists scaledger_public;
create schema if not exists scaledger_private;


-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Types
create type scaledger_public.account_type as enum (
  'asset',
  'equity',
  'expense',
  'liability',
  'revenue',
  'contra'
);

comment on type scaledger_public.account_type is 'The possible types of accounts';


create type scaledger_public.currency as enum (
  'AED', 'AFN', 'ALL', 'AMD', 'ANG', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN', 'BAM', 'BBD', 'BDT', 'BGN', 'BHD', 'BIF',
  'BMD', 'BND', 'BOB', 'BRL', 'BSD', 'BTN', 'BWP', 'BYR', 'BZD', 'CAD', 'CDF', 'CHF', 'CLP', 'CNY', 'COP', 'CRC',
  'CUC', 'CUP', 'CVE', 'CZK', 'DJF', 'DKK', 'DOP', 'DZD', 'EGP', 'ERN', 'ETB', 'EUR', 'FJD', 'FKP', 'GBP', 'GEL',
  'GGP', 'GHS', 'GIP', 'GMD', 'GNF', 'GTQ', 'GYD', 'HKD', 'HNL', 'HRK', 'HTG', 'HUF', 'IDR', 'ILS', 'IMP', 'INR',
  'IQD', 'IRR', 'ISK', 'JEP', 'JMD', 'JOD', 'JPY', 'KES', 'KGS', 'KHR', 'KMF', 'KPW', 'KRW', 'KWD', 'KYD', 'KZT',
  'LAK', 'LBP', 'LKR', 'LRD', 'LSL', 'LYD', 'MAD', 'MDL', 'MGA', 'MKD', 'MMK', 'MNT', 'MOP', 'MRO', 'MUR', 'MVR',
  'MWK', 'MXN', 'MYR', 'MZN', 'NAD', 'NGN', 'NIO', 'NOK', 'NPR', 'NZD', 'OMR', 'PAB', 'PEN', 'PGK', 'PHP', 'PKR',
  'PLN', 'PYG', 'QAR', 'RON', 'RSD', 'RUB', 'RWF', 'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD', 'SHP', 'SLL', 'SOS',
  'SPL', 'SRD', 'STD', 'SVC', 'SYP', 'SZL', 'THB', 'TJS', 'TMT', 'TND', 'TOP', 'TRY', 'TTD', 'TVD', 'TWD', 'TZS',
  'UAH', 'UGX', 'USD', 'UYU', 'UZS', 'VEF', 'VND', 'VUV', 'WST', 'XAF', 'XCD', 'XDR', 'XOF', 'XPF', 'YER', 'ZAR',
  'ZMW', 'ZWD'
);


-- Global table Functions
create function scaledger_private.set_updated_at() returns trigger as $$
begin
  new.updated_at := current_timestamp;
  return new;
end;
$$ language plpgsql;


create function scaledger_public.graphql_subscription() returns trigger as $$
declare
  v_event text = TG_ARGV[0];
  v_topic text = TG_ARGV[1];
begin
  perform pg_notify(v_topic, json_build_object(
    'event', v_event,
    'subject', new.id
  )::text);
  return new;
end;
$$ language plpgsql volatile set search_path from current;


-- Core Ledger Acounting
create table scaledger_public.accounts (
  id               uuid primary key default uuid_generate_v4(),
  created_at       timestamp default now(),
  updated_at       timestamp default now(),
  type             scaledger_public.account_type not null,
  name             text not null check (char_length(name) < 255),
  code             text,
  metadata         jsonb
);

create unique index on scaledger_public.accounts (code);

create trigger account_updated_at before update
  on scaledger_public.accounts
  for each row
  execute procedure scaledger_private.set_updated_at();

comment on table scaledger_public.accounts is 'An account to which every posting belongs';
comment on column scaledger_public.accounts.id is 'The primary unique identifier for the account';
comment on column scaledger_public.accounts.created_at is 'The account’s time created';
comment on column scaledger_public.accounts.updated_at is 'The account’s last updated time';
comment on column scaledger_public.accounts.type is 'The account’s type';
comment on column scaledger_public.accounts.name is 'The account’s name';
comment on column scaledger_public.accounts.code is 'An alphanumeric account code to identify the account';
comment on column scaledger_public.accounts.metadata is 'A dictionary of arbitrary key-values';


create table scaledger_public.postings (
  id                uuid primary key default uuid_generate_v4(),
  credit_id         uuid not null references scaledger_public.accounts(id) on delete restrict,
  debit_id          uuid not null references scaledger_public.accounts(id) on delete restrict,
  currency          scaledger_public.currency not null,
  created_at        timestamp default now(),
  amount            bigint not null check(amount <= 9007199254740991 AND amount >= 0), -- @note to support JavaScripts 2^53 - 1 maximum value
  external_id       text not null,
  metadata          jsonb
);

create unique index on scaledger_public.postings (external_id);
create index on scaledger_public.postings (amount);
create index on scaledger_public.postings (credit_id);
create index on scaledger_public.postings (debit_id);
create index on scaledger_public.postings (currency);
create index on scaledger_public.postings (created_at);

create trigger posting_created
  after insert on scaledger_public.postings
  for each row
  execute procedure scaledger_public.graphql_subscription(
    'posting_created',  -- "event"
    'graphql:posting'   -- "topic"
  );

comment on table scaledger_public.postings is 'A record of a credit/debt (amount) on an account';
comment on column scaledger_public.postings.id is 'The primary unique identifier for the posting';
comment on column scaledger_public.postings.credit_id is 'The account to which the amount is credited';
comment on column scaledger_public.postings.debit_id is 'The account to which the amount is debited';
comment on column scaledger_public.postings.currency is 'The currency the amount is denominated in';
comment on column scaledger_public.postings.created_at is 'The posting’s time created';
comment on column scaledger_public.postings.amount is 'The amount (credit/debit) applied in the transaction';
comment on column scaledger_public.postings.metadata is 'A dictionary of arbitrary key-values';

-- VIEWs

create view scaledger_public.ledger as
select account_ledger.*, accounts.name as "account_name" from (
  select sum(account_balances.balance) as "balance", account_balances.account_id, account_balances.currency from (
    select
      sum(postings.amount) as "balance",
      postings.credit_id as "account_id",
      postings.currency
    from scaledger_public.postings
    group by postings.credit_id, postings.currency
    union
    select
      sum(postings.amount * -1) as "balance",
      postings.debit_id as "account_id",
      postings.currency
    from scaledger_public.postings
    group by postings.debit_id, postings.currency
  ) as account_balances
  group by account_balances.account_id, account_balances.currency
) as account_ledger
left join scaledger_public.accounts on account_ledger.account_id = accounts.id;

comment on view scaledger_public.ledger is 'A global ledger view of all accounts';


commit;