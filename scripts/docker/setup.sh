#!/bin/bash
set -e
set -x

# Install dependencies
bundle check || bundle install || true
yarn install --frozen-lockfile
