---
name: dot-llm framework project
description: What dot-llm is, repo layout, the CLI subcommands, and key conventions
type: project
originSessionId: 507d571c-f4de-4425-8d7c-cb5b12395a28
---
**Repo:** `/Users/gaspar/agentic-workspace/dot-llm` locally; remote at `git@github.com:rntgspr/dot-llm.git` (HTTPS: `https://github.com/rntgspr/dot-llm.git`).

**What it is:** spec-driven, agent-friendly knowledge structure for codebases. Lives at `.llm/` in any project that adopts it. Distilled from the jetpay-frontend pilot.

**Layout:**
```
dot-llm/
├── llm                      ← bash CLI entry point (resolves symlinks via _resolve_self)
├── src/cmd_*.sh             ← subcommand modules sourced by llm
├── dot-llm-framework/       ← starter copied by `llm install` to a project's .llm/
├── skills/<name>/SKILL.md   ← published skills in Anthropic format (git, llm-cli)
└── .llm/                    ← dogfood (mostly empty)
```

**CLI subcommands** (current surface; see `llm help`):
- `doctor [--quiet]` — default; tree-wide health check with RAW and marker guards
- `install [--with <skill>...]` / `uninstall [--yes]` — fixed `.llm/` target, no custom target path
- `intake <KEY> [--tracker <name>]` — fetch tracker issue → `.llm/intake/<KEY>/` (adapters: jira, linear, clickup; Basecamp TODO)
- `update [<path>] [--from <src>] [--keep-prose] [--apply]` plus `update skills|commands|schema` — steady-state framework update; refuses on version mismatch; schema uses a dedicated destructive path
- `tag` / `tag <file>` / `tag get|set <file> <tag>` — `<!-- llm:NAME -->` block ops (schema reader — see [[v3_deferred]])
- `flow <src> <verb> [<dst>]` — guarded file ops inside `.llm/`
- `upgrade` — reruns install.sh and performs the distribution integrity check

**Env vars:**
- `DOT_LLM_DIR` is fixed to `.llm` in `src/common.sh`.
- `.env` at the project root is auto-loaded by `llm intake` only.

**Key v4 conventions:**
- Marker blocks: `<!-- llm:NAME -->` ... `<!-- /llm:NAME -->`. Marker NAME = path through the schema's node tree, colon-joined (`llm:plans:plan:handoff:files`). **v4: every block body is a `[Link, Description]` markdown table — hardcoded shape, no per-tag column declarations.**
- Tag bodies + frontmatter values = adopter-owned; prose = framework-owned. See [[feedback_update_design]].
- Every md under `.llm/` carries `human_revised: false`; flip to `true` after a human pass. Schema declares required FM keys with a `!` suffix.
- `llm doctor` warns for lingering RAW blocks; `llm flow` resolves symlinked parents canonically and refuses escapes.
- `temp-archive-flow.delete-me.md` is the transient work file under `archive/<PLAN-ID>/` between archive Phase 1 and Phase 2.
- `.env`, `CLAUDE.md`, `.llm`, and `**/*.bkp.*` are gitignored.
- v4 model details (recursive node tree, tracker-agnostic intake, universal `[Link, Description]` tag shape) live in [[v4_model]].

**Pilot adopter:** `jetpay-frontend`.

**Brew formula** (planned, not implemented): `Formula/dot-llm.rb` in a tap repo. Auto-bump via `mislav/bump-homebrew-formula-action` on release tags.

**Skill-gated capabilities:** git mutations require `.llm/skills/git/SKILL.md` present; without it, every role uses git for reading only.
