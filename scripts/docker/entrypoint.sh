#!/bin/bash
set -e
set -x
scripts/docker/setup.sh

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

# yarn install
# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
