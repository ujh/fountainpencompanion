#!/usr/bin/env bash
# collect-trace.sh <session-id> <execution-file> <dest>
#
# Collects this run's Claude Code session (the main transcript and the
# per-subagent transcripts) and a copy of the execution file in a staging
# directory, replaces the tokens in REDACT_GITHUB_TOKEN and
# REDACT_CLAUDE_TOKEN with [REDACTED], and only then moves the result to
# <dest>. It exits non-zero without creating <dest> when REDACT_GITHUB_TOKEN
# is empty or something that looks like a token is left after redacting.
set -euo pipefail

[ "$#" -eq 3 ] || { echo "usage: collect-trace.sh <session-id> <execution-file> <dest>" >&2; exit 2; }
[ -n "${REDACT_GITHUB_TOKEN:-}" ] || { echo "collect-trace.sh: REDACT_GITHUB_TOKEN is empty" >&2; exit 1; }

session_id="$1"
execution_file="$2"
dest="$3"

mkdir -p "$(dirname "$dest")"
staging="$(mktemp -d "$(dirname "$dest")/.collect-trace.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

if [ -n "$execution_file" ] && [ -f "$execution_file" ]; then
  cp "$execution_file" "$staging/execution.json"
fi

shopt -s nullglob
if [ -n "$session_id" ]; then
  for found in "$HOME"/.claude/projects/*/"$session_id".jsonl "$HOME"/.claude/projects/*/"$session_id"; do
    project="$staging/transcripts/$(basename "$(dirname "$found")")"
    mkdir -p "$project"
    mv "$found" "$project/"
  done
fi

redact() {
  local file
  while IFS= read -r -d '' file; do
    SECRET="$1" perl -pi -e 's/\Q$ENV{SECRET}\E/[REDACTED]/g' "$file"
  done < <(find "$staging" -type f -print0)
}

redact "$REDACT_GITHUB_TOKEN"
redact "$(printf 'x-access-token:%s' "$REDACT_GITHUB_TOKEN" | base64 | tr -d '\n')"
if [ -n "${REDACT_CLAUDE_TOKEN:-}" ]; then
  redact "$REDACT_CLAUDE_TOKEN"
fi

if grep -rqE 'gh[pousr]_[A-Za-z0-9]{36}|sk-ant-[a-z0-9]+-[A-Za-z0-9_-]{40,}' "$staging"; then
  echo "collect-trace.sh: a token is left after redacting; not collecting the trace" >&2
  exit 1
fi

rm -rf "$dest"
mv "$staging" "$dest"
trap - EXIT
