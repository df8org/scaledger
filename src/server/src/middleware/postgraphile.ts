import { postgraphile, makePluginHook } from "postgraphile";
import simplifyInflector from "@graphile-contrib/pg-simplify-inflector";
import forceBigInt from "../plugins/force-big-int";
import e from "express";
import subscriptions from "../plugins/subscriptions";
import PgPubsub from "@graphile/pg-pubsub";

const pluginHook = makePluginHook([PgPubsub]);

const postgraphileOptions = (app: e.Application) => {
  return {
    appendPlugins: [simplifyInflector, forceBigInt, subscriptions],
    watchPg: true,
    dynamicJson: true,
    enhanceGraphiql: true,
    graphiql: true,
    sortExport: true,
    // @TODO make this automatically commit 
    exportGqlSchemaPath: process.env.BUILD_SCHEMA ? `${__dirname}/../../src/schema.graphql` : null,
    retryOnInitFail: true,
    subscriptions: true,
    pluginHook
  }
};

export default async (app: e.Application) => {  
  app.use(postgraphile(
    process.env.DATABASE_URL,
    "scaledger_public",
    postgraphileOptions(app)
  ));
};