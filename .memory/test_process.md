---
name: dot-llm-test-process
description: The repeatable manual test cycle for exercising the llm CLI against the test bench
metadata: 
  node_type: memory
  type: project
  originSessionId: ea685735-0853-461c-af23-330eda256308
---

Repeatable cycle for testing the `llm` CLI end-to-end. Run it against the test bench (see [[test_bench]]: `bulbasaur/ext-api-cad`).

**Steps (in order):**
1. Use the test repo (`bulbasaur/ext-api-cad`), not throwaway `/tmp` trees.
2. **Always run `llm uninstall` first** — reset any prior install to a clean slate.
3. Verify the `.llm/` directory was completely removed from the test project (no leftover files; git status clean for the `.llm/` path).
4. Start the install (`llm install`).
5. Create any command that might be needed ahead of time — e.g. post-install commands / slash commands — before testing.
6. Test the command(s) that were created/installed.
7. Write a short, simple report here in the chat.

**Why:** Renato wants a deterministic, repeatable bench so CLI changes are validated against a real codebase the same way every time, with the bench left installed as a fixture between runs (uninstall-first resets it at the start of each cycle).

**How to apply:** When validating any `llm` change (new subcommand, behavior change), run this exact cycle. The bench is left INSTALLED at the end — the next cycle's uninstall-first step is what cleans it. Respect [[feedback_git_readonly]] on the bench repo: do not commit or mutate its git history; `.llm/` is not gitignored there, but `.claude/` and `CLAUDE.md` are.
