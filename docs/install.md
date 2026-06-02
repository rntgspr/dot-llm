# `llm install`

Install a framework flavor into a project's `.llm/`. Copies the chosen flavor wholesale, auto-installs the universal `llm-*` skills, optionally layers opt-in skills, asks which agent client to wire (`claude`, `codex`, or `both`), writes the matching instruction-file hook, wires a real `UserPromptSubmit` context hook, and copies slash commands into the selected agent command directories.

## Usage

```
llm install [--framework <name>] [--agent <claude|codex|both>] [--with <skill>...]
```

| Option | Default | Description |
|---|---|---|
| `--framework <name>` | `sdlc-it-project-basic` | Which flavor to install. `base` resolves to `frameworks/__base/`; any other name to `frameworks/<name>/`. |
| `--agent <target>` | asks interactively (`claude` in non-interactive runs) | Which client to wire: `claude`, `codex`, or `both`. Controls hooks, skills, and slash-command placement. |
| `--with <skill>` | none | Add an opt-in skill at install time. Repeatable. `llm-*` skills don't need `--with` — they ship automatically. |

The install location is always `.llm/` at the project root.

## What it does

1. **Pre-checks** — prompts before replacing an existing `.llm/` (refuses non-interactive overwrite) and verifies each requested `--with <skill>` exists at `skills/<skill>/SKILL.md`.
2. **Copies the chosen flavor wholesale, then prunes framework-owned subdirs from `.llm/`** — `cp -R "frameworks/<flavor>" .llm/` followed by `rm -rf .llm/{skills,commands}`. Brings the schema, starter indexes, templates, roles. Skills and slash commands live under the selected agent project dirs; they do NOT belong inside `.llm/`.
3. **Installs framework skills** — for every `llm-*` directory under `frameworks/<flavor>/skills/`, copies the dir to `.claude/skills/<name>/`, `.codex/skills/<name>/`, or both. Universal skills (`llm-doctor`, `llm-install`, `llm-update`) live in `__base/skills/` and are mirrored verbatim into every flavor (drift-checked at install-script time), so sourcing only from the flavor is complete.
4. **Applies opt-in skills** — for each `--with <name>`, copies the top-level `skills/<name>/` dir into the selected agent skill directory or directories.
5. **Wires agent instructions** — creates or appends a `<!-- BEGIN DOT-LLM-HOOK --> ... <!-- END DOT-LLM-HOOK -->` block containing an `@.llm/index.md` import directive. Claude uses `CLAUDE.md`; Codex uses `AGENTS.md`. Idempotent — skips if the marker is already present.
6. **Wires context hooks** — installs `.llm/hooks/context-loader.sh` and adds a `UserPromptSubmit` command hook to `.claude/settings.json`, `.codex/hooks.json`, or both. The JSON update is done with `jq`. On every prompt, the hook uses `llm tag all --rows` to read canonical `<!-- llm:* -->` tag bodies, resolves `[Link, Description]` rows, and injects root context plus linked files whose Link or Description matches the prompt subject.
7. **Installs slash commands** — recursively copies every `*.md` from `frameworks/<flavor>/commands/` into `.claude/commands/`, `.codex/commands/`, or both. A file at `frameworks/<flavor>/commands/llm/doctor.md` becomes `<agent>/commands/llm/doctor.md`, exposing the slash command as `/llm:doctor` where the client supports project commands. Universal commands (`/llm:doctor`, `/llm:update`, `/llm:resolve`) live in `__base/commands/` and are mirrored verbatim into every flavor.
8. **Prints next steps** — hints to edit the components table in `.llm/domain.md`, populate `meta.apps.values` in `.llm/schema.yaml`, and run `llm doctor`.

## Available flavors

- **`sdlc-it-project-basic`** *(default)* — software delivery lifecycle: `intake/`, `plans/`, `archive/`, `specs/`, `exploring/` pillars; Lead/Dev/Ghost roles; ships five flavor-specific skills (`llm-intake`, `llm-explore`, `llm-plan`, `llm-specs`, `llm-archive`).
- **`iac-basic`** — tool-agnostic infrastructure-as-code workflow: durable `topology/` (apply-order DAG) + `runbooks/` pillars alongside the lifecycle pillars (`intake/`, `plans/`, `archive/`, `exploring/`); `apps:` enumerates environments; Lead/Dev roles; ships six flavor-specific skills (`llm-intake`, `llm-explore`, `llm-plan`, `llm-topology`, `llm-archive`, `llm-arch`).
- **`qa-basic`** — test-strategy & coverage workflow: durable `coverage/` + `standards/` pillars alongside the lifecycle pillars; `apps:` enumerates test levels; ships five flavor-specific skills (`llm-intake`, `llm-explore`, `llm-plan`, `llm-coverage`, `llm-archive`).
- **`base`** — minimal kernel (resolves to `frameworks/__base/`): no pillars, only the rules + meta sections of the schema. Start here to build a custom domain from scratch.

The one-line summary shown by `llm install --help` per flavor comes from each flavor's `domain.md` H1.

Adding a new flavor is a disk operation — create `frameworks/<name>/` with its own self-contained `schema.yaml` and starter files. Install's help text auto-discovers it.

## Available skills

**Universal** (authored in `__base/skills/`, mirrored verbatim into every flavor):
- `llm-doctor`, `llm-install`, `llm-update` — multi-step orchestration carried by SKILL.md.

**Flavor-shipped** (live in `frameworks/<flavor>/skills/` alongside the universal copies):
- `sdlc-it-project-basic` adds `llm-intake`, `llm-explore`, `llm-plan`, `llm-specs`, `llm-archive`.
- `iac-basic` adds `llm-intake`, `llm-explore`, `llm-plan`, `llm-topology`, `llm-archive`, `llm-arch`.
- `qa-basic` adds `llm-intake`, `llm-explore`, `llm-plan`, `llm-coverage`, `llm-archive`.

**Opt-in** (sourced from top-level `skills/`; require `--with <name>`):
- `git` — unlocks mutating git commands (`commit`, `push`, `reset`, ...) under the framework's skill-gated capability rule.
- `terraform`, `pulumi` — IaC tool mechanics plus the iac-basic safety discipline (the plan/preview diff IS the blast radius; environments along the promotion path).
- `pytest`, `vitest`, `cypress`, `playwright` — test-runner mechanics; companions to the qa-basic flavor.

Opt-ins combine with any flavor. `llm install --help` auto-discovers them from each `skills/<name>/SKILL.md` `description:`.

## Available slash commands

**Universal** (authored in `__base/commands/llm/`, mirrored verbatim into every flavor):
- `/llm:doctor`, `/llm:update`, `/llm:resolve` — pure mechanics, no flavor-specific content.

**Flavor-specific** (live in `frameworks/<flavor>/commands/llm/`):
- `sdlc-it-project-basic` ships `/llm:archive`, `/llm:explore`, `/llm:intake`, `/llm:plan`, `/llm:specs`.
- `iac-basic` ships `/llm:archive`, `/llm:explore`, `/llm:intake`, `/llm:plan`, `/llm:topology` (the `llm-arch` skill has no command — it triggers on conversation).
- `qa-basic` ships `/llm:archive`, `/llm:explore`, `/llm:intake`, `/llm:plan`, `/llm:coverage`.

## CLI primitives (no skill needed)

`llm tag` (read/write `<!-- llm:NAME -->` marker blocks; schema-validated) and `llm flow` (4 verbs: `move`/`copy`/`create`/`remove`, with guardrails) are mechanical primitives — composed by recipe skills, documented in `llm <cmd> --help`.

To inspect all canonical tag bodies:

```bash
llm tag all --body
```

## When to use

Run once per project, at adoption time. To re-install after deleting `.llm/`, just run `llm install` again. To upgrade an existing install with new framework files, see [`llm update`](update.md).

## Examples

```bash
llm install                                                  # install the SDLC flavor at .llm/
llm install --agent codex                                    # Codex hook + .codex assets
llm install --agent both --with git                          # Claude and Codex hooks/assets
llm install --framework base                                 # minimal kernel
llm install --with git                                       # SDLC + git skill
llm install --framework sdlc-it-project-basic                # explicit flavor
llm install --framework base --with git                      # base + git
llm install --framework iac-basic --with terraform           # IaC flavor + tool skill
llm install --framework qa-basic --with pytest --with vitest # QA flavor + runners
```

## Related

- [`llm doctor`](doctor.md) — first thing to run after install.
- [`llm update`](update.md) — keep an installed `.llm/` up to date with a newer framework version.
- [`llm uninstall`](uninstall.md) — reverse of install.
