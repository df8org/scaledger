import { makeExtendSchemaPlugin, gql } from "graphile-utils";

export default makeExtendSchemaPlugin(({ pgSql: sql }) => ({
  typeDefs: gql`
    type PostingCreatedSubscriptionPayload {
      # This is populated by our resolver below
      posting: Posting

      # This is returned directly from the PostgreSQL subscription payload (JSON object)
      event: String
    }

    extend type Subscription {
      postingCreated: PostingCreatedSubscriptionPayload @pgSubscription(topic: "posting_created")
    }
  `,

  resolvers: {
    PostingCreatedSubscriptionPayload: {
      // This method finds the user from the database based on the event
      // published by PostgreSQL.
      //
      // In a future release, we hope to enable you to replace this entire
      // method with a small schema directive above, should you so desire. It's
      // mostly boilerplate.
      async posting(
        event,
        _args,
        _context,
        { graphile: { selectGraphQLResultFromTable } }
      ) {
        const rows = await selectGraphQLResultFromTable(
          sql.fragment`scaledger_public.postings`,
          (_tableAlias, sqlBuilder) => {
            sqlBuilder.where(
              sql.fragment`${sqlBuilder.getTableAlias()}.id = ${sql.value(
                event.subject
              )}`
            );
          }
        );
        return rows[0];
      },
    },
  },
}));