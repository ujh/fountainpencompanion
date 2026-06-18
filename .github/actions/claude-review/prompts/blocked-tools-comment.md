# Blocked-tools PR comment

Use this body verbatim when posting the blocked-tools comment,
substituting the actual `<tool name>` / `<blocked command/args>`
entries:

> **Reviewer tools blocked during this run**
>
> The reviewer attempted these tools but the CI permission
> gate rejected them, so it had to work around the gap:
>
> - `<tool name>`: `<blocked command/args>`
> - ...
>
> If a maintainer's security review of these calls says they're
> safe, add them to the `--allowedTools` list in
> `.github/actions/claude-review/action.yml` so future reviews
> don't have to improvise.
>
> ⚠️ Do **not** blanket-allow `Bash` or use
> `--dangerously-skip-permissions`. The reviewer reads PR
> content (diff, commit messages, comments) as input, so a
> malicious PR can prompt-inject the reviewer into running
> shell. With broad permissions that means the Claude auth
> token, `GITHUB_TOKEN`, and anything else in the job env can
> be exfiltrated via `curl` / `wget` / etc. Allowlist
> specific tools and narrow command patterns (e.g.
> `Bash(gh pr view:*)`) instead.
