-- This script will delete everything created in `schema.sql`. This script is
-- also idempotent, you can run it as many times as you would like. Nothing
-- will be dropped if the schemas and roles do not exist.

begin;

drop schema if exists public, scaledger_public, scaledger_hidden, scaledger_private cascade;
drop role if exists anonymous;
drop role if exists signed_in;

commit;