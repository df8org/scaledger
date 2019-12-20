# Dockerfile

# Global args, set before the first FROM, shared by all stages
ARG NODE_ENV="production"

################################################################################
# Build stage 1 - `npm install`

FROM node:12-alpine as builder
# Import our shared args
ARG NODE_ENV

# Cache node_modules for as long as possible
COPY package.json package-lock.json /app/
WORKDIR /app/
RUN npm install --production=false --no-progress

# Copy over the server source code

COPY src/ /app/src

# Run the build
COPY tsconfig.json postgraphile.tags.json5 /app/
RUN npm run build

################################################################################
# Build stage 2 - COPY the relevant things (multiple steps)

FROM node:12-alpine as clean
# Import our shared args
ARG NODE_ENV

# Copy over selectively just the tings we need, try and avoid the rest
COPY --from=builder /app/package.json /app/package-lock.json /app/postgraphile.tags.json5 /app/
COPY --from=builder /app/dist/ /app/dist/

################################################################################
# Build stage FINAL - COPY everything, once, and then do a clean `npm install`

FROM node:12-alpine
# Import our shared args
ARG NODE_ENV

EXPOSE 5000
WORKDIR /app/
# Copy everything from stage 2, it's already been filtered
COPY --from=clean /app/ /app/

# Install deps
RUN npm install --production=true --no-progress

LABEL description="An accounting ledger for developers"

# You might want to disable GRAPHILE_TURBO if you have issues
ENV GRAPHILE_TURBO=1
ENV NODE_ENV=$NODE_ENV
ENTRYPOINT npm run start