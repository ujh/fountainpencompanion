import { readFileSync } from "node:fs";
import { join } from "node:path";

const ACTION = readFileSync(
  join(process.cwd(), ".github/actions/claude-review/action.yml"),
  "utf8"
);
const WORKFLOW = readFileSync(
  join(process.cwd(), ".github/workflows/claude-code-review.yml"),
  "utf8"
);

const step = (name) => {
  const start = ACTION.indexOf(`    - name: ${name}\n`);
  if (start === -1) throw new Error(`no step named ${name}`);
  const end = ACTION.indexOf("\n    - ", start + 1);
  return ACTION.slice(start, end === -1 ? undefined : end);
};

const claudeStep = () => {
  const start = ACTION.indexOf("    - uses: anthropics/claude-code-action@");
  return ACTION.slice(start, ACTION.indexOf("\n    - ", start + 1));
};

describe("claude-review action wiring", () => {
  it("runs the reviewer under the session id the trace is collected for", () => {
    expect(claudeStep()).toContain("--session-id ${{ steps.trace.outputs.session_id }}");
    expect(step("Collect reviewer trace")).toContain(
      "SESSION_ID: ${{ steps.trace.outputs.session_id }}"
    );
  });

  it("gives the trace collection both tokens to redact", () => {
    const collect = step("Collect reviewer trace");

    expect(collect).toContain("REDACT_GITHUB_TOKEN: ${{ github.token }}");
    expect(collect).toContain("REDACT_CLAUDE_TOKEN: ${{ inputs.claude_code_oauth_token }}");
  });

  it("uploads the trace only after it was collected and redacted", () => {
    expect(step("Upload reviewer trace")).toContain(
      "if: always() && steps.collect_trace.outcome == 'success'"
    );
  });

  it("does not fail the review when the trace cannot be collected or uploaded", () => {
    expect(step("Collect reviewer trace")).toContain("continue-on-error: true");
    expect(step("Upload reviewer trace")).toContain("continue-on-error: true");
  });

  it("checks out without leaving the checkout token in the git config", () => {
    const start = WORKFLOW.indexOf("- uses: actions/checkout@");
    const checkout = WORKFLOW.slice(
      start,
      WORKFLOW.indexOf("- uses: ./.github/actions/claude-review")
    );

    expect(checkout).toContain("persist-credentials: false");
  });

  it("names the artifact and its retention in one place for the upload and the comment", () => {
    const upload = step("Upload reviewer trace");
    const report = step("Report denied tool calls");

    expect(upload).toContain("name: ${{ steps.trace.outputs.artifact }}");
    expect(upload).toContain("retention-days: ${{ steps.trace.outputs.retention_days }}");
    expect(report).toContain(
      "TRACE_ARTIFACT: ${{ steps.upload_trace.outputs.artifact-id != '' && steps.trace.outputs.artifact || '' }}"
    );
    expect(report).toContain("TRACE_RETENTION_DAYS: ${{ steps.trace.outputs.retention_days }}");
  });

  it("uploads the trace before the report that mentions it", () => {
    expect(ACTION.indexOf("- name: Upload reviewer trace")).toBeLessThan(
      ACTION.indexOf("- name: Report denied tool calls")
    );
  });
});
