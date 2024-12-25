# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t dummy .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name dummy dummy

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.3.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /app

ENV BUNDLE_PATH="/usr/local/bundle"

# The development stage is used to run the app locally as serves as the base for building the version
# that will contain the data for prod.
FROM base AS dev
# Install base packages
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y curl libjemalloc2 libvips lsb-release gnupg2 && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Postgres 16, so that schema dumping works
RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
# Trust the PGDG gpg key
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc| gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
# Install packages needed to build gems
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y build-essential git pkg-config libpq-dev postgresql-client-16 && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
  rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
  bundle exec bootsnap precompile --gemfile

# Install npm packages
COPY .nvmrc package.json yarn.lock ./
RUN if [ $(uname -m) = "aarch64" ]; then NODE_ARCH=arm64 ; else NODE_ARCH=x64 ; fi; \
  uname -m && \
  NODE_VERSION=$(cat .nvmrc) && \
  NODE_TAR_FILE="node-$NODE_VERSION-linux-$NODE_ARCH.tar.gz" && \
  curl -s "https://nodejs.org/dist/$NODE_VERSION/$NODE_TAR_FILE" --output $NODE_TAR_FILE && \
  mkdir -p /opt/nodejs && \
  tar -xvzf "$NODE_TAR_FILE" -C /opt/nodejs/ && \
  mv "/opt/nodejs/node-$NODE_VERSION-linux-$NODE_ARCH" "/opt/nodejs/current" && \
  ln -s /opt/nodejs/current/bin/node /usr/local/bin/node && \
  ln -s /opt/nodejs/current/bin/npm /usr/local/bin/npm && \
  rm "node-$NODE_VERSION-linux-$NODE_ARCH.tar.gz" && \
  node -v

RUN npm install --global yarn && ln -s /opt/nodejs/current/bin/yarn /usr/local/bin/yarn
RUN yarn install

EXPOSE 80

# Entrypoint script always runs, even if command is overwritten
ENTRYPOINT ["/app/config/docker/dev-entrypoint.sh"]

# CMD script doesn't run if command is overwritten (e.g. for migrations)
CMD ["bundle exec puma"]

FROM dev AS build

# Copy application code
COPY . .

# Bundle again, but without dev and test groups
ENV RAILS_ENV="production" \
  BUNDLE_DEPLOYMENT="1" \
  BUNDLE_WITHOUT="development:test"

RUN rm -rf "${BUNDLE_PATH}" && \
  bundle install && \
  rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
  bundle exec bootsnap precompile --gemfile

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 PRECOMPILING_ASSETS=true ./bin/rails assets:precompile

# Final stage for app image
FROM base AS prod

# Install packages needed to run the app
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y libpq5 && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /app /app

EXPOSE 80

# Entrypoint script always runs, even if command is overwritten
ENTRYPOINT ["/app/config/docker/entrypoint.sh"]

# CMD script doesn't run if command is overwritten (e.g. for migrations)
CMD ["bundle exec puma"]
