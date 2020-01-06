// @ts-ignore
export default (builder) => {
  // @ts-ignore
  builder.hook("build", build => {
    // Dangerously force BigInt into Int - BigInt columns must have 2^53-1 limit constraints to work with JavaScript
    build.pgRegisterGqlTypeByTypeId(
      "20",
      () => build.graphql.GraphQLInt
    );
    return build;
  });
};