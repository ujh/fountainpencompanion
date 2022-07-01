#!/bin/bash
set -e
set -x

if [[ $@ =~ 'webpack' ]]
then
  yarn install --frozen-lockfile
else
  bundle check || bundle install || true
  # Remove a potentially pre-existing server.pid for Rails.
  rm -f /app/tmp/pids/server.pid
fi

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
