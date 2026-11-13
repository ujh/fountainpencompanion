// Reads the reviewer's execution file (the SDK message log written by
// claude-code-action) and reports on it from the workflow, not from the model:
//
//   node review-result.mjs report   list denied tool calls in the step summary
//                                   and in one PR comment that is kept current
//   node review-result.mjs check    fail the job when the reviewer errored
//
// Environment: EXECUTION_FILE, and for `report` also GITHUB_STEP_SUMMARY,
// GITHUB_TOKEN, REPO, PR_NUMBER, HEAD_SHA and RUN_URL.
import { appendFileSync, readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

export const MARKER = "<!-- claude-review-denied-tools -->";
export const BOT_LOGIN = "github-actions[bot]";
const EXPECTED_DENIALS = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"]);
const MAX_CALL_LENGTH = 300;

export const resultOf = (messages) => messages.findLast((message) => message.type === "result");

export const reviewerFailed = (messages) => {
  const result = resultOf(messages);
  return !result || result.is_error === true;
};

const describeInput = (input = {}) =>
  input.command ?? input.file_path ?? input.pattern ?? JSON.stringify(input);

const oneLine = (text) => {
  const flat = String(text).replace(/\s+/g, " ").trim();
  return flat.length > MAX_CALL_LENGTH ? `${flat.slice(0, MAX_CALL_LENGTH)}…` : flat;
};

export const deniedCalls = (messages) => {
  const denials = resultOf(messages)?.permission_denials ?? [];
  const calls = denials
    .filter((denial) => !EXPECTED_DENIALS.has(denial.tool_name))
    .map((denial) => `${denial.tool_name}: ${oneLine(describeInput(denial.tool_input))}`);
  return [...new Set(calls)];
};

const codeBlock = (calls) => calls.map((call) => `    ${call}`);

export const summarySection = (calls) =>
  ["### Denied tool calls", "", ...(calls.length ? codeBlock(calls) : ["None."]), ""].join("\n");

export const commentBody = (calls, { runUrl, sha }) => {
  const run = `[the latest run](${runUrl}) on ${sha.slice(0, 7)}`;
  if (!calls.length) {
    return [MARKER, `**Reviewer tools blocked:** none in ${run}.`].join("\n");
  }
  return [
    MARKER,
    "**Reviewer tools blocked during the latest run**",
    "",
    `The CI permission gate rejected these calls in ${run}, so the reviewer had to work around them:`,
    "",
    ...codeBlock(calls),
    "",
    "If a maintainer's security review of these calls says they're safe, add them to the " +
      "`--allowedTools` list in `.github/actions/claude-review/action.yml` so future reviews " +
      "don't have to improvise.",
    "",
    "⚠️ Do **not** blanket-allow `Bash` or use `--dangerously-skip-permissions`. The reviewer " +
      "reads PR content as input, so a malicious PR can prompt-inject it into running shell, " +
      "which could exfiltrate the Claude token and `GITHUB_TOKEN`. Allowlist specific commands " +
      "and check each for flags that run other programs or write files."
  ].join("\n");
};

const github =
  (fetchImpl, token) =>
  async (url, options = {}) => {
    const response = await fetchImpl(url, {
      ...options,
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${token}`,
        "X-GitHub-Api-Version": "2022-11-28",
        ...(options.body ? { "Content-Type": "application/json" } : {})
      }
    });
    if (!response.ok) {
      throw new Error(`${options.method ?? "GET"} ${url} failed with ${response.status}`);
    }
    return response.json();
  };

const findStickyComment = async (request, commentsUrl) => {
  for (let page = 1; ; page++) {
    const comments = await request(`${commentsUrl}?per_page=100&page=${page}`);
    const sticky = comments.find(
      (comment) => comment.user?.login === BOT_LOGIN && comment.body?.startsWith(MARKER)
    );
    if (sticky) return sticky;
    if (comments.length < 100) return null;
  }
};

export const upsertComment = async ({ calls, repo, pr, token, runUrl, sha, fetchImpl = fetch }) => {
  const request = github(fetchImpl, token);
  const commentsUrl = `https://api.github.com/repos/${repo}/issues/${pr}/comments`;
  const sticky = await findStickyComment(request, commentsUrl);
  if (!sticky && !calls.length) return "none";

  const body = JSON.stringify({ body: commentBody(calls, { runUrl, sha }) });
  if (sticky) {
    await request(`https://api.github.com/repos/${repo}/issues/comments/${sticky.id}`, {
      method: "PATCH",
      body
    });
    return "updated";
  }
  await request(commentsUrl, { method: "POST", body });
  return "created";
};

const readMessages = (path) => JSON.parse(readFileSync(path, "utf8"));

const report = async (env) => {
  const calls = deniedCalls(readMessages(env.EXECUTION_FILE));
  appendFileSync(env.GITHUB_STEP_SUMMARY, summarySection(calls));
  const outcome = await upsertComment({
    calls,
    repo: env.REPO,
    pr: env.PR_NUMBER,
    token: env.GITHUB_TOKEN,
    runUrl: env.RUN_URL,
    sha: env.HEAD_SHA
  });
  console.log(`${calls.length} denied tool call(s); PR comment: ${outcome}`);
};

const check = (env) => {
  if (reviewerFailed(readMessages(env.EXECUTION_FILE))) {
    console.log("::error::The reviewer ended with an error, so this PR was not reviewed.");
    process.exitCode = 1;
  }
};

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const command = process.argv[2];
  if (command === "report") await report(process.env);
  else if (command === "check") check(process.env);
  else {
    console.error("usage: review-result.mjs report|check");
    process.exitCode = 2;
  }
}
