import {
  BOT_LOGIN,
  MARKER,
  commentBody,
  deniedCalls,
  reviewerFailed,
  summarySection,
  upsertComment
} from "../../../.github/actions/claude-review/scripts/review-result.mjs";

const result = (fields = {}) => ({
  type: "result",
  subtype: "success",
  is_error: false,
  ...fields
});
const denial = (tool_name, tool_input) => ({ tool_name, tool_use_id: "toolu_1", tool_input });

describe("reviewerFailed", () => {
  it("is false for a successful run", () => {
    expect(reviewerFailed([{ type: "system" }, result()])).toBe(false);
  });

  it("is true when the result is an error, even with a success subtype", () => {
    expect(reviewerFailed([result({ is_error: true })])).toBe(true);
  });

  it("is true when the run never produced a result", () => {
    expect(reviewerFailed([{ type: "system" }, { type: "assistant" }])).toBe(true);
  });
});

describe("deniedCalls", () => {
  it("lists each denied call once with its command", () => {
    const messages = [
      result({
        permission_denials: [
          denial("Bash", { command: "git diff HEAD | grep foo" }),
          denial("Bash", { command: "git diff HEAD | grep foo" }),
          denial("Read", { file_path: "/etc/passwd" })
        ]
      })
    ];

    expect(deniedCalls(messages)).toEqual(["Bash: git diff HEAD | grep foo", "Read: /etc/passwd"]);
  });

  it("leaves out the file-writing tools the reviewer is denied on purpose", () => {
    const messages = [
      result({
        permission_denials: [
          denial("Write", { file_path: "a" }),
          denial("Edit", { file_path: "b" }),
          denial("Bash", { command: "find . -name x" })
        ]
      })
    ];

    expect(deniedCalls(messages)).toEqual(["Bash: find . -name x"]);
  });

  it("flattens multi-line commands so they cannot break out of the code block", () => {
    const messages = [
      result({ permission_denials: [denial("Bash", { command: "echo a\n\n# Heading\n@someone" })] })
    ];

    expect(deniedCalls(messages)).toEqual(["Bash: echo a # Heading @someone"]);
  });

  it("truncates long commands", () => {
    const messages = [
      result({ permission_denials: [denial("Bash", { command: "x".repeat(500) })] })
    ];

    expect(deniedCalls(messages)[0]).toBe(`Bash: ${"x".repeat(300)}…`);
  });

  it("falls back to the JSON input for tools without a command or path", () => {
    const messages = [result({ permission_denials: [denial("WebFetch", { url: "https://x" })] })];

    expect(deniedCalls(messages)).toEqual(['WebFetch: {"url":"https://x"}']);
  });

  it("is empty when nothing was denied or there is no result", () => {
    expect(deniedCalls([result()])).toEqual([]);
    expect(deniedCalls([])).toEqual([]);
  });
});

describe("summarySection", () => {
  it("lists the calls as an indented code block", () => {
    expect(summarySection(["Bash: ls /"])).toBe("### Denied tool calls\n\n    Bash: ls /\n");
  });

  it("says none when nothing was denied", () => {
    expect(summarySection([])).toBe("### Denied tool calls\n\nNone.\n");
  });
});

describe("commentBody", () => {
  const context = { runUrl: "https://run", sha: "abcdef1234567" };

  it("starts with the marker and lists the calls as an indented code block", () => {
    const body = commentBody(["Bash: jq -n env"], context);

    expect(body.startsWith(`${MARKER}\n`)).toBe(true);
    expect(body).toContain("[this run](https://run) on abcdef1");
    expect(body).toContain("\n\n    Bash: jq -n env\n\n");
  });
});

describe("upsertComment", () => {
  const options = { repo: "o/r", pr: "7", token: "t", runUrl: "https://run", sha: "abcdef1" };
  const commentsUrl = "https://api.github.com/repos/o/r/issues/7/comments";

  const fakeFetch = (pages) =>
    vi.fn(async (url) => {
      const page = Number(new URL(url).searchParams.get("page") ?? 0);
      return { ok: true, json: async () => pages[page - 1] ?? {} };
    });

  const sticky = { id: 42, user: { login: BOT_LOGIN }, body: `${MARKER}\nold` };

  it("creates a comment when there is none yet", async () => {
    const fetchImpl = fakeFetch([[{ id: 1, user: { login: "ujh" }, body: MARKER }]]);

    const outcome = await upsertComment({ ...options, calls: ["Bash: x"], fetchImpl });

    expect(outcome).toBe("created");
    const [url, request] = fetchImpl.mock.calls.at(-1);
    expect(url).toBe(commentsUrl);
    expect(request.method).toBe("POST");
    expect(JSON.parse(request.body).body).toContain("    Bash: x");
    expect(request.headers.Authorization).toBe("Bearer t");
  });

  it("updates the bot's existing comment instead of adding another", async () => {
    const fetchImpl = fakeFetch([[sticky]]);

    const outcome = await upsertComment({ ...options, calls: ["Bash: y"], fetchImpl });

    expect(outcome).toBe("updated");
    const [url, request] = fetchImpl.mock.calls.at(-1);
    expect(url).toBe("https://api.github.com/repos/o/r/issues/comments/42");
    expect(request.method).toBe("PATCH");
  });

  it("finds the existing comment on a later page", async () => {
    const filler = Array.from({ length: 100 }, (_, id) => ({ id, user: { login: "x" }, body: "" }));
    const fetchImpl = fakeFetch([filler, [sticky]]);

    expect(await upsertComment({ ...options, calls: ["Bash: y"], fetchImpl })).toBe("updated");
  });

  it("leaves the PR alone when nothing was denied, even with an earlier comment", async () => {
    const fetchImpl = fakeFetch([[sticky]]);

    expect(await upsertComment({ ...options, calls: [], fetchImpl })).toBe("none");
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it("raises when GitHub rejects the request", async () => {
    const fetchImpl = vi.fn(async () => ({ ok: false, status: 403 }));

    await expect(upsertComment({ ...options, calls: ["Bash: x"], fetchImpl })).rejects.toThrow(
      "GET https://api.github.com/repos/o/r/issues/7/comments?per_page=100&page=1 failed with 403"
    );
  });
});
