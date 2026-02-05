#!/bin/bash -ex

cd /app


bundle check || bundle install || true

if [[ $@ =~ 'yarn' ]]
then
  yarn install --frozen-lockfile
else
  # Remove a potentially pre-existing server.pid for Rails.
  rm -rf /app/tmp/pids/server.pid
fi

# Since we specified both an ENTRYPOINT and a CMD (which could be overwritten
# by a "command"), Docker passes the CMD/command to the ENTRYPOINT script as
# arguments.  So we can run the CMD/command with exec "$@".
exec "$@"
