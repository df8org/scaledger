SET search_path TO scaledger_public, public;

begin;


insert into accounts (name, type) values
  ('Founders', 'equity'),
  ('Cash', 'asset'),
  ('Accounts Payable', 'liability'),
  ('Accounts Receivable', 'asset');

insert into postings(external_id, amount, credit_id, debit_id, currency, metadata)
	select uuid_generate_v4() as external_id, floor(random()*(100000-500+1))+500 as amount, credit_id, debit_id, 'USD' as currency, '{"order_id": "123"}' as metadata
  from
    generate_series(1, 1000) as series,
    (select id::uuid from accounts) as credit_id (credit_id),
    (select id::uuid from accounts) as debit_id (debit_id)
	where credit_id != debit_id;


commit;
