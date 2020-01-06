require('dotenv').config()

import express from "express";
import postgrahile from "./middleware/postgraphile";

const app = express();

async function main() {
  await postgrahile(app);

  app.listen(process.env.PORT);
}

main();