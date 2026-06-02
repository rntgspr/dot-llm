---
name: dot-llm-test-bench
description: The real project used as a manual test bench for the llm CLI and .llm/ framework
metadata: 
  node_type: memory
  type: project
  originSessionId: ea685735-0853-461c-af23-330eda256308
---

Test bench for exercising the `llm` CLI and the `.llm/` framework against a real codebase: **`/Users/gaspar/agentic-workspace/bulbasaur/ext-api-cad`**.

- It is a real Python project (FastAPI-style: `main.py`, `pyproject.toml` + `poetry.lock`, `pytest.ini`, `src/`, `tests/`). Agent name for that workspace folder is `bulbasaur`.
- As of 2026-05-21 it has **no `.llm/` directory yet** — so installing the framework there (`llm install`) is itself part of the test flow.

**Why:** Renato wants a concrete, persistent target to dogfood `llm` subcommands (`tag`, `doctor`, `install`, `regen`, etc.) instead of throwaway `/tmp` trees.

**How to apply:** When validating CLI behavior end-to-end, prefer running against this project rather than scratch dirs in `/tmp`. Operate with `DOT_LLM_DIR=/Users/gaspar/agentic-workspace/bulbasaur/ext-api-cad/.llm` (once installed). It is a separate repo (`bulbasaur` workspace) — respect the [[feedback_git_readonly]] rule there too; do not mutate its git state.

Note: this is the bench for testing the *tooling*; distinct from `jetpay-frontend`, which was the original *pilot adopter* the framework was distilled from. See [[dot-llm]].
