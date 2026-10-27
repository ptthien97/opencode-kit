// finder-first (OpenCode V2): block grep/glob and shell search (grep/rg/ag/ack/find/fd)
// until the session has actually called a Finder tool. After one Finder attempt
// (success or error) native search is unlocked for that session.
// Disable: FINDER_FIRST=0
//
// V2 reads `id` + `setup()` and ignores V1 `server()` hooks; a throw inside
// `execute.before` makes the tool call fail with this message.

const SEARCH_TOOLS = new Set(["grep", "glob"]);
const SHELL_TOOLS = new Set(["shell", "bash"]);
const SHELL_SEARCH = /(^|[\s;&|(`$])(grep|egrep|fgrep|rg|ag|ack|find|fd)\s/;
// A real Finder call inside Code Mode, not just the word "finder" in a string.
const EXECUTE_FINDER = /tools\s*\.\s*finder\b|tools\s*\[\s*["']finder["']\s*\]/;

const MSG =
  "BLOCKED by finder-first: codebase search MUST use Finder first. " +
  "Call `execute` with: await tools.finder['index-status']({workspace_full_path:'<repo root>'}) then " +
  "await tools.finder.finder({workspace_full_path:'<repo root>', query:'...'}). " +
  "After one Finder attempt (even if it errors/returns empty), grep/glob are unlocked.";

// Brief-driven agents: the planner already did discovery and named exact files.
const EXEMPT_AGENTS = new Set(["worker"]);

const tried = new Set();

function isFinderCall(tool, input) {
  if (/^finder[_-]/i.test(tool)) return true;
  if (tool === "execute" && EXECUTE_FINDER.test(String(input?.code ?? ""))) return true;
  return false;
}

export default {
  id: "user.finder-first",
  async setup(ctx) {
    if (process.env.FINDER_FIRST === "0") return;
    await ctx.tool.hook("execute.before", (event) => {
      const { tool, sessionID, input, agent } = event;
      if (EXEMPT_AGENTS.has(String(agent ?? ""))) return;
      if (isFinderCall(tool, input)) {
        tried.add(sessionID);
        return;
      }
      if (tried.has(sessionID)) return;
      if (SEARCH_TOOLS.has(tool)) throw new Error(MSG);
      if (SHELL_TOOLS.has(tool) && SHELL_SEARCH.test(String(input?.command ?? ""))) {
        throw new Error(MSG);
      }
    });
  },
};
