---
human_revised: false
version: 1
name: llm-install
description: Use this skill whenever the user wants to adopt the dot-llm framework in a project — install the .llm/ tree, choose a flavor, choose the agent target (Claude, Codex, or both), wire the matching instruction file, and (post-install) bootstrap the spec areas for an existing codebase. Trigger on phrases like "install the framework", "set up .llm/ here", "adopt dot-llm", "instala o framework", "bootstrap specs from the codebase", "scaffold the spec areas", "compactar / consolidate area X", "deepen the auth spec", or any request to seed/grow the `specs/` pillar. The install itself is deterministic (copy framework files + skills + slash commands); the spec bootstrap that follows is LLM-driven via this skill.
---

# `llm install` — adopt the framework + bootstrap specs

`llm install` is a **deterministic, mechanical copy** — it doesn't make judgment calls. The judgment work (which components the project ships, which spec areas exist) is **your job** as the LLM, guided by this skill, **after** the copy completes.

## Install (mechanical)

```bash
llm install                                        # default flavor: sdlc-it-project-basic
llm install --agent codex                          # Codex hook + .codex assets
llm install --agent both                           # Claude and Codex hooks/assets
llm install --framework base                       # minimal kernel only (no pilares)
llm install --framework sdlc-it-project-basic
llm install --with git                             # default flavor + opt-in skill(s)
```

What the script does, in order:
1. Resolves the chosen flavor → `frameworks/<name>/` (or `frameworks/__base/` for `base`).
2. Prompts before replacing an existing `.llm/`; rejects non-interactive overwrite.
3. Copies the flavor wholesale into `.llm/`.
4. **Auto-installs every `llm-*` skill** from the flavor into the selected agent skill dirs (`.claude/skills/`, `.codex/skills/`, or both) — these are the operating skills the LLM needs for any work in this tree.
5. Applies `--with <skill>` opt-ins from the top-level `skills/` directory.
6. Wires the selected agent instruction file (`CLAUDE.md` for Claude, `AGENTS.md` for Codex) with a `<!-- BEGIN/END DOT-LLM-HOOK -->` block that `@`-imports `.llm/index.md` so every selected agent session in the project auto-loads the framework entry point. Idempotent (skip-if-marker-present).
7. Installs slash commands into the selected agent command dirs (`.claude/commands/`, `.codex/commands/`, or both).

After step 7, the script prints "Next steps" — that's your cue to start the spec bootstrap below.

## Post-install (LLM work — start here)

The framework is in place; the codebase is not yet mapped to it. **Your job** is to seed `specs/` so future plans have somewhere to absorb deltas. Do these in order, **with user confirmation on each judgment call**.

### Step 1 — Components

`.llm/domain.md` has a `<!-- llm:components -->` table with placeholder rows (`webapp`, `api`). Replace them with the project's actual components.

1. Read the project's `README`, `package.json`/`pyproject.toml`/`go.mod`/etc., and the top-level dir layout to identify components (a "component" is typically a deployable surface or a coherent codebase chunk).
2. Propose the list to the user. Don't auto-decide.
3. Use `llm tag set domain.md components` to write the table (v4 — every body is `[Link, Description]`):
   ```
   | Link              | Description                                            |
   |-------------------|--------------------------------------------------------|
   | [webapp](../web/) | Next.js + TypeScript front-end at `web/`               |
   | [api](../api/)    | FastAPI + Python 3.12 service at `api/`                |
   ```
4. Update `.llm/schema.yaml > meta.apps.values` to list those same keys (in addition to the reserved `platform` and `meta`).
5. Run `llm doctor` — `[✓] Schema conformance` should hold.

### Step 2 — Hand off to `llm-specs` for the spec bootstrap

With components declared, the next post-install step is seeding `specs/` so future plans have somewhere to absorb deltas. **That work lives in the flavor-specific `llm-specs` skill** (it carries the bootstrap / deepen / consolidate recipes). When the user is ready, invoke it — `llm-specs` walks them through:

- **Bootstrap** — identify functional areas (`auth`, `payments`, …) and create skeleton `specs/<area>/index.md` per area, with user confirmation on every split.
- **Deepen** — fill an area's EARS requirements grounded in code; split into concerns / subareas as warranted.
- **Consolidate** — compact accumulated deltas into a single coherent spec when `deltas:` grows long.

This skill stops at Step 1 because the spec work is recurring (deepen + consolidate happen across the project's lifetime, not just at install). Keeping it in `llm-specs` lets non-sdlc flavors install without that overhead.

## Uninstall

Reverse of install — uninstall is mostly file ops with safety guardrails on `index.md` and pillar roots. Use when resetting a bench for testing.

```bash
llm uninstall                # interactive confirm; refuses non-TTY without --yes
llm uninstall --yes          # non-interactive (agents / CI)
```

## Patterns

| User says | You do |
|---|---|
| "Install the framework here" | `llm install` → walk through Step 1 (components) → hand off to `llm-specs` for the spec bootstrap |
| "Set up dot-llm for this project" | Same as above |
| "Bootstrap the specs" / "deepen X" / "consolidate Y" | Not this skill — hand off to `llm-specs` (carries those recipes) |
| "Add a flavor" / "install with the X flavor" | `llm install --framework <name>` (default = sdlc-it-project-basic) |
