FROM ruby:2.7.6

ENV APP_ROOT /app
ENV BUNDLE_PATH "/usr/local/bundle"
ENV GEM_PATH "/usr/local/bundle"

WORKDIR $APP_ROOT

COPY Gemfile.lock .nvmrc $APP_ROOT/

RUN apt-get update && \
    apt-get install -y curl gnupg && \
    apt-key adv --fetch-keys https://dl.yarnpkg.com/debian/pubkey.gpg && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install -y postgresql-client-13 yarn && \
    gem install bundler -v "$(grep -A1 "BUNDLED WITH" Gemfile.lock | tail -n1 | xargs)" && \
    if [ $(uname -m) = "aarch64" ]; then NODE_ARCH=arm64 ; else NODE_ARCH=x64 ; fi; \
    uname -m && \
    NODE_VERSION=$(cat .nvmrc) && \
    NODE_TAR_FILE="node-v$NODE_VERSION-linux-$NODE_ARCH.tar.gz" && \
    curl -s "https://nodejs.org/dist/v$NODE_VERSION/$NODE_TAR_FILE" --output $NODE_TAR_FILE && \
    mkdir -p /opt/nodejs && \
    tar -xvzf "$NODE_TAR_FILE" -C /opt/nodejs/ && \
    mv "/opt/nodejs/node-v$NODE_VERSION-linux-$NODE_ARCH" "/opt/nodejs/current" && \
    ln -s /opt/nodejs/current/bin/node /usr/local/bin/node && \
    rm "node-v$NODE_VERSION-linux-$NODE_ARCH.tar.gz" && \
    node -v

ENTRYPOINT ["scripts/docker/entrypoint.sh"]
EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
