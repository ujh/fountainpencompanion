import { execFileSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const SCRIPT = join(process.cwd(), ".github/actions/claude-review/scripts/collect-trace.sh");
const GITHUB_TOKEN = "ghs_exampleGithubToken123";
const CLAUDE_TOKEN = "sk-ant-oat01-exampleClaudeToken_456";

describe("collect-trace.sh", () => {
  let root, home, dest, project;

  beforeEach(() => {
    root = mkdtempSync(join(tmpdir(), "collect-trace-"));
    home = join(root, "home");
    dest = join(root, "out/trace");
    project = join(home, ".claude/projects/-workspace");
    mkdirSync(join(project, "this-run/subagents"), { recursive: true });
    writeFileSync(join(project, "this-run.jsonl"), "main\n");
    writeFileSync(join(project, "this-run/subagents/agent-1.jsonl"), "subagent\n");
    writeFileSync(join(project, "other-run.jsonl"), "other\n");
  });

  afterEach(() => rmSync(root, { recursive: true, force: true }));

  const run = (sessionId, executionFile = "", env = {}) =>
    execFileSync("bash", [SCRIPT, sessionId, executionFile, dest], {
      env: {
        ...process.env,
        HOME: home,
        REDACT_GITHUB_TOKEN: GITHUB_TOKEN,
        REDACT_CLAUDE_TOKEN: CLAUDE_TOKEN,
        ...env
      },
      stdio: "pipe"
    });

  const collectedFiles = () =>
    [
      join(dest, "transcripts/-workspace/this-run.jsonl"),
      join(dest, "transcripts/-workspace/this-run/subagents/agent-1.jsonl"),
      join(dest, "execution.json")
    ].map((path) => readFileSync(path, "utf8"));

  const leaveInEveryFile = (content) => {
    writeFileSync(join(project, "this-run.jsonl"), content);
    writeFileSync(join(project, "this-run/subagents/agent-1.jsonl"), content);
    const executionFile = join(root, "execution.json");
    writeFileSync(executionFile, content);
    return executionFile;
  };

  it("moves this run's main and subagent transcripts and leaves other sessions", () => {
    run("this-run");

    const collected = join(dest, "transcripts/-workspace");
    expect(readFileSync(join(collected, "this-run.jsonl"), "utf8")).toBe("main\n");
    expect(readFileSync(join(collected, "this-run/subagents/agent-1.jsonl"), "utf8")).toBe(
      "subagent\n"
    );
    expect(existsSync(join(collected, "other-run.jsonl"))).toBe(false);
    expect(existsSync(join(project, "other-run.jsonl"))).toBe(true);
  });

  it("copies the execution file when there is one", () => {
    const executionFile = join(root, "execution.json");
    writeFileSync(executionFile, "[]");

    run("this-run", executionFile);

    expect(readFileSync(join(dest, "execution.json"), "utf8")).toBe("[]");
  });

  it("collects no transcripts without a session id", () => {
    run("");

    expect(existsSync(join(dest, "transcripts"))).toBe(false);
    expect(existsSync(join(project, "this-run.jsonl"))).toBe(true);
  });

  it("succeeds with an empty trace when the run left no transcripts and no execution file", () => {
    run("missing-run", join(root, "missing.json"));

    expect(readdirSync(dest)).toEqual([]);
  });

  it("redacts both tokens, also inside a checkout auth header, in every collected file", () => {
    const header = Buffer.from(`x-access-token:${GITHUB_TOKEN}`).toString("base64");
    const executionFile = leaveInEveryFile(
      `url=https://x-access-token:${GITHUB_TOKEN}@github.com ${CLAUDE_TOKEN} basic ${header}\n`
    );

    run("this-run", executionFile);

    for (const content of collectedFiles()) {
      expect(content).toBe(
        "url=https://x-access-token:[REDACTED]@github.com [REDACTED] basic [REDACTED]\n"
      );
    }
  });

  it("redacts only the GitHub token when no Claude token is given", () => {
    const executionFile = leaveInEveryFile(`token ${GITHUB_TOKEN} here\n`);

    run("this-run", executionFile, { REDACT_CLAUDE_TOKEN: "" });

    for (const content of collectedFiles()) {
      expect(content).toBe("token [REDACTED] here\n");
    }
  });

  it("refuses to collect anything without the GitHub token to redact", () => {
    const executionFile = leaveInEveryFile(`${GITHUB_TOKEN}\n`);

    expect(() => run("this-run", executionFile, { REDACT_GITHUB_TOKEN: "" })).toThrow();

    expect(existsSync(join(root, "out"))).toBe(false);
    expect(existsSync(join(project, "this-run.jsonl"))).toBe(true);
  });

  it("refuses to collect anything when a token it was not given is left", () => {
    const otherToken = `ghs_${"a".repeat(36)}`;
    const executionFile = leaveInEveryFile(`${otherToken}\n`);

    expect(() => run("this-run", executionFile)).toThrow();

    expect(existsSync(dest)).toBe(false);
    expect(readdirSync(join(root, "out"))).toEqual([]);
  });

  it("refuses to collect anything when a Claude token it was not given is left", () => {
    const executionFile = leaveInEveryFile(`sk-ant-oat01-${"b".repeat(80)}\n`);

    expect(() => run("this-run", executionFile)).toThrow();

    expect(existsSync(dest)).toBe(false);
  });
});
