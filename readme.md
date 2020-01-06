# Scaledger

[![pipeline status](https://gitlab.com/df8org/scaledger/badges/master/pipeline.svg)](https://gitlab.com/df8org/scaledger/commits/master)

A double-entry accounting database with a typed GraphQL API, supporting:

- Immutable entries 
- An API introspected directly from a PostgreSQL schema
- GraphQL subscriptions for real-time updates

## Basics

Scaledger is designed to be used as a service for recording transactions (called `postings`) between `accounts`, and reporting their balances through an entity called `ledger`. This is particularly useful when you have to track the balances for thousands, or even millions, of individual user accounts such as in the case of marketplaces.

To use it, you deploy it as part of your service architecture and connect over a GraphQL interface. Documentation this interface is available at [http://localhost:5000/graphiql](http://localhost:5000/graphiql)

First, create some `account`s:

```
mutation {
  createAccount(input: {account: {type: EQUITY, name: "Y Combinator Seed"}}) {
    account {
      id
    }
  }
}

mutation {
  createAccount(input: {account: {type: ASSET, name: "Cash"}}) {
    account {
      id
    }
  }
}
```

Next, create a `posting` between them:

```
mutation {
  createPosting(input: { posting: {
    creditId: "5c70baa8-f917-4220-afad-1521fdecb5a7",
    debitId: "9c42c59a-7404-47f2-9a63-fb3a8ecab111",
    currency: USD,
    amount: 15000000,
    externalId: "yc-safe-transfer"
  }})
}
```

You'll notice that the `amount` field is denominated in the minor value of the currency. This is important - don't use floats for accounting systems! Next, you'll notice `currency` - Scaledger is natively multi-currency and supports all of the ISO 4217 currency codes. If you're wondering what `externalId` is, that's required so that each `posting` from a downstream service is idempotent - as a defense against you sending the same request twice.

Both `account` and `posting` also support a `metadata` field which can be used to store abitrary key/value JSON dictionaries of extra data. Like any good ledger, `posting` cannot be mutated after it is created - to void a transaction you need to reverse it by creating an inverted one.

The general ledger can be queried after `posting`s are created:

```
query {
  ledgers {
    nodes {
      accountName
      balance
      currency
    }
  }
}
```

Lastly, Scaledger also supports WebSockets for newly created postings via the GraphQL Subscription primitive:

```
subscription {
  postingCreated {
    posting {
      amount
      id
    }
  }
}
```

## Stack

Scaledger uses a purpose-built PostgreSQL schema and provides a GraphQL API.

### Services
- *scaledger-db*: a PostgreSQL database and ledger schema
- *scaledger-server*: a node-based [PostGraphile](https://www.graphile.org/) GraphQL API

## Development

scaledger includes a `docker-compose` configuration out of box.

1. Clone the project
2. [Install Docker Compose](https://docs.docker.com/compose/install/)
3. `cd docker`
4. Build images with `./scripts/images`
5. `docker-compose up`

By default, your first initialization of the container will automatically run the schema. Depending on how you've installed docker, you may need to prefix `sudo` on `docker-compose` up and on any of the scripts in `docker/scripts`.

If you'd like to create test data, run `./scripts/seed` from inside of `docker`. You can run `./seed` at any point to return the test data and schema to an initial state.

If you wish to recreate the database, or reset it, without any seed data you can run `./schema` instead.

To connect to the docker container running the database with `psql` run `./scripts/psql`.

### Services In Development
- View `scaledger-server`'s GraphiQL testbed at [http://localhost:5000/graphiql](http://localhost:5000/graphiql)
- `scaledger-server` is mounted at [http://localhost:5000/](http://localhost:5000)
- `scaledger-db` runs on `5432`, use `./scripts/psql` to run a console