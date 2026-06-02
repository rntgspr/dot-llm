---
name: dot-llm-frameworks-layout
description: Multi-flavor framework layout — frameworks/__base kernel + frameworks/<name>/ variants; how install resolves them; universal vs flavor-specific skills
metadata: 
  node_type: memory
  type: project
  originSessionId: ea685735-0853-461c-af23-330eda256308
---

The dot-llm repo is **multi-flavor**. Each flavor is **self-contained** (its own `schema.yaml` + starter files); the adopter picks one at install time. No merging, no inheritance.

## Repo layout

```
dot-llm/
├── llm                                 # CLI entry
├── src/cmd_*.sh                        # universal CLI modules
├── frameworks/
│   ├── __base/                         # minimal kernel — universal rules + meta, no pillars
│   │   ├── schema.yaml
│   │   ├── index.md
│   │   └── templates/any-index.md
│   └── sdlc-it-project-basic/          # default flavor
│       ├── schema.yaml
│       ├── index.md
│       ├── {intake,plans,archive,specs,exploring}/
│       ├── templates/
│       ├── roles/
│       └── skills/                     # flavor-shipped skills (one per pillar that needs orchestration)
│           ├── llm-intake/SKILL.md    # mirror tracker issues into intake/
│           ├── llm-explore/SKILL.md   # bootstrap + promote/drop exploring/
│           ├── llm-plan/SKILL.md      # author plans, tasks, handoffs, delta-draft
│           ├── llm-specs/SKILL.md     # bootstrap + deepen + consolidate specs/
│           └── llm-archive/SKILL.md   # close+archive plans, absorb delta into specs/
└── skills/                             # UNIVERSAL skills (auto-installed for every flavor) + opt-ins
    ├── llm-{doctor,install,sync}/      # 3 universal (auto) — multi-step orchestration
    └── git/                            # opt-in (--with git)
```

## Skill classification

**Skills exist only where there's real multi-step orchestration that can't fit in `--help`.** CLI primitives (mechanical, single-step, well-served by `--help`) ship without a skill.

- **Universal skills** (top-level `skills/llm-*/`, auto-installed everywhere): `llm-doctor`, `llm-install`, `llm-sync`. Each carries multi-step workflow (e.g. `llm-install`'s post-install Step 1, `llm-sync`'s key-drift adjudication, `llm-doctor`'s orphan-row reconciliation). `llm-install` Steps 2/3/4 (spec bootstrap/deepen/consolidate) were extracted into the sdlc-shipped `llm-specs` since they're sdlc-specific recurring work, not install-time work.
- **Flavor-specific skills** (`frameworks/<flavor>/skills/llm-*/`, ship via wholesale flavor copy): five for sdlc — `llm-intake`, `llm-explore`, `llm-plan`, `llm-specs`, `llm-archive` — covering each pillar that needs orchestration (intake mirror, exploring lifecycle, plan authoring, spec maintenance, plan archival).
- **Opt-in skills** (non-`llm-*` at top-level `skills/`, via `--with <name>`): `git`.
- **CLI-only (no skill)**: `llm tag`, `llm flow`. Primitives whose semantics fit cleanly in `llm <cmd> --help`. Skills that compose them (intake, archive, install post-install) reference `llm tag get/set` and `llm flow move/copy/...` in their recipe bodies — no separate skill needed.

**Operational simplification note (2026-06-15):** the install target is fixed to `.llm/`; `llm update` gained dedicated `skills`, `commands`, and `schema` targets; `llm doctor` owns the RAW-block warning; `llm flow` now rejects dotted directory names and resolves paths canonically before every mutation.

**v4 note:** every `<!-- llm:* -->` body is `[Link, Description]` (hardcoded). Schema files no longer declare per-tag columns — only `host_file:` routing for meta tags. The same universal shape applies to flavor-shipped pillar indexes and to opt-in skills' marker blocks alike.

**Why:** the dispatch cost of a skill (loading its full SKILL.md into context) is only earned when there's orchestration the LLM needs guidance for. Documenting 4 verbs + 4 guardrails is the help text's job, not a skill's.

## Install order (cmd_install.sh)

1. Wholesale `cp -R "$framework_src" "$target"` — brings the flavor's `skills/` (and everything else) into target.
2. Auto-install loop over top-level `skills/llm-*/`: **skip-if-exists** (so flavor overrides of a universal name are preserved).
3. Opt-in `--with <name>` skills layered last.

`cp -R "$SKILLS_SRC"/llm-*/` requires stripping the glob's trailing slash (BSD `cp -R src/ dest/` copies contents, not the dir as a subdir). Use `clean="${llm_skill%/}"`.

## CLI conventions

- `DEFAULT_FRAMEWORK="sdlc-it-project-basic"` in the entry script (`llm`).
- `_resolve_framework_src <name>` echoes the source dir: `base` → `frameworks/__base/`, anything else → `frameworks/<name>/`.
- `llm install --framework <name>` (default applied when flag absent). Same flag on `llm sync`.
- Help text is **dynamically generated** from disk. `_install_list_frameworks` walks `frameworks/` and skips dirs prefixed with `__` (internal/kernel convention). `_install_list_skills` parses each top-level `skills/*/SKILL.md` `description:` field, skipping `llm-*` (auto-installed) so only opt-ins are listed.
- **No per-flavor `scripts/` extension** — removed when no flavor needed it.

## Field conventions

- **Pillar-level `tracker:`** (on `intake/index.md` of sdlc-it-project-basic): **a list** like `[jira]` — the set of trackers this project pulls from.
- **Item-level `tracker:`** (on each `intake/<KEY>/index.md`): **scalar** — records which tracker that specific item came from. Required field per schema.

**Why:** unambiguous provenance per item even in multi-tracker projects.

## How to apply

- New flavor → create `frameworks/<name>/` with its own self-contained `schema.yaml` + starter files. If the flavor needs domain-specific skills, drop them under `frameworks/<name>/skills/llm-*/` — they'll auto-ship with install.
- New universal skill → drop under top-level `skills/llm-<name>/`. Auto-installed everywhere on next install.
- Changing the default flavor → update `DEFAULT_FRAMEWORK` in the entry script.
- `cmd_intake.sh` reads templates from `$DOT_LLM_DIR/templates/` (adopter's installed copy) — decoupled from the source checkout.
