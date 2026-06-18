#!/usr/bin/env bash
#
# Submit a batched PR review with multiple inline comments via a single
# call to GitHub's "Create a review for a pull request" endpoint.
#
# The Claude reviewer cannot do this directly because the API needs a
# JSON body with a comments[] array, and the two ways to deliver it
# (`gh api --input <file>` and `gh api --input -` via stdin) both
# require either the `Write` tool (not allowlisted: it has no path
# scoping) or shell constructs like pipes / `<` redirection (banned
# by the allowlist policy in prompts/base.md).
#
# This helper is the narrow, audited bridge: a single bash entry point
# that takes structured args, JSON-encodes everything via `jq --arg /
# --args` so payload content is never interpreted as shell, and pipes
# the result to `gh api --input -` internally.
#
# Usage:
#   ./.claude-review-post <repo> <pr> <commit_sha> <event> \
#     [<path> <line> <body>] ...
#
# Arguments:
#   <repo>        owner/name, e.g. urbanhafner/fountainpencompanion
#   <pr>          pull request number
#   <commit_sha>  head SHA of the PR (must be a hex string)
#   <event>       one of: COMMENT, APPROVE, REQUEST_CHANGES
#   <path> <line> <body>   zero or more inline-comment triples
#
# Notes:
#   - All input validation rejects unexpected characters before any
#     downstream call. Repo names are restricted to [A-Za-z0-9._/-],
#     PR numbers must be digits, and the commit SHA must be hex.
#   - The `gh` CLI uses the runner's GITHUB_TOKEN; this script does
#     not handle auth.

set -euo pipefail

if [ "$#" -lt 4 ]; then
  echo "usage: $0 <repo> <pr> <commit_sha> <event> [<path> <line> <body>]..." >&2
  exit 2
fi

repo=$1
pr=$2
commit=$3
event=$4
shift 4

case "$repo" in
  ''|*[!A-Za-z0-9._/-]*)
    echo "bad repo: $repo" >&2; exit 2;;
esac

case "$pr" in
  ''|*[!0-9]*)
    echo "bad pr: $pr" >&2; exit 2;;
esac

case "$commit" in
  ''|*[!A-Fa-f0-9]*)
    echo "bad commit_sha: $commit" >&2; exit 2;;
esac

case "$event" in
  COMMENT|APPROVE|REQUEST_CHANGES) ;;
  *)
    echo "bad event: $event (must be COMMENT, APPROVE, or REQUEST_CHANGES)" >&2
    exit 2;;
esac

remaining=$#
if [ $((remaining % 3)) -ne 0 ]; then
  echo "comment args must come in (path, line, body) triples; got $remaining trailing args" >&2
  exit 2
fi

i=0
for arg in "$@"; do
  if [ $((i % 3)) -eq 1 ]; then
    case "$arg" in
      ''|*[!0-9]*)
        echo "bad line value at comment $((i / 3 + 1)): '$arg' (must be a positive integer)" >&2
        exit 2;;
    esac
  fi
  i=$((i + 1))
done

comments=$(
  jq -n --args '
    [ $ARGS.positional as $a
      | range(0; ($a | length); 3) as $i
      | { path: $a[$i], line: ($a[$i+1] | tonumber), side: "RIGHT", body: $a[$i+2] }
    ]
  ' -- "$@"
)

jq -n \
  --arg commit "$commit" \
  --arg event "$event" \
  --argjson comments "$comments" \
  '{commit_id: $commit, event: $event, comments: $comments}' \
| gh api \
    "repos/$repo/pulls/$pr/reviews" \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    --input -
