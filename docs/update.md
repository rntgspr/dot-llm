# `llm update`

Steady-state update of an installed `.llm/` tree from a fresh framework source. Also replaces the installed **skills** and **slash commands** from the source. In the general update, **adopter data inside `.llm/` is never overwritten** — frontmatter values are preserved, tag bodies are preserved, only prose around them takes updates from the source. The explicit `schema --apply` target is the destructive exception.

## Usage

```
llm update [<path>] [--from <src>] [--keep-prose] [--apply]
llm update skills [--from <src>] [--apply]
llm update commands [--from <src>] [--apply]
llm update schema [--from <src>] [--apply]
```

| Argument / flag | Description |
|---|---|
| `<path>` | Scope to a directory or file inside `.llm/`. Omit for full tree. |
| `skills` | Preview or replace only installed framework skills. Does not update `.llm/` files or commands. |
| `commands` | Preview or replace only installed slash commands. Does not update `.llm/` files or skills. |
| `schema` | Diff or replace `.llm/schema.yaml`. The general update never merges the schema mechanically. |
| `--from <src>` | Source: a local dot-llm checkout path or a git URL. Default: the active checkout. |
| `--keep-prose` | Preserve local prose outside marker blocks (warns per file). Default: prose comes from source. |
| `--apply` | Apply the selected update. For the general flow, merges `.llm/` files and replaces skills/commands; for `schema`, replaces the local schema wholesale. |

## Flavor detection

Update reads `flavor:` from the installed `.llm/schema.yaml`, then selects the
matching framework under `<source>/frameworks/<flavor>/`. The `base` flavor
resolves to `<source>/frameworks/__base/`. If `flavor:` is absent, update falls
back to `base`.

There is no `--framework` flag: update refreshes the flavor already installed
in the project. To change flavors, uninstall the current tree and install the
new flavor.

## What gets updated

### `.llm/` files — three regions per file

#### 1. Frontmatter

**Adopter values are kept verbatim.** Update only reports **key drift** — keys the source has that local lacks (and vice-versa) — so the LLM can reconcile against `schema.yaml`. **Never rewrites a frontmatter value.**

When update reports key drift, the LLM's job is:
- Source-only key → add it to the local file with a value inferred from what `schema.yaml` says the field means.
- Local-only key → either it's adopter-added (harmless), or schema declares it and source is stale (investigate), or it's a stale field from a prior framework version (consider removing).

#### 2. Tag bodies (`<!-- llm:NAME -->` blocks)

**v4: every tag body is a `[Link, Description]` markdown table.** The shape is hardcoded — schemas don't declare per-tag columns.

**Local body is preserved.** A marker present in source but absent locally is **added empty** (so new framework tags appear). The dry-run labels each tag:

| Label | Meaning |
|---|---|
| `[=]` | local body present and matches the table shape — preserved |
| `[?]` | local block is empty — populate with `[Link, Description]` rows |
| `[Δ]` | local body is NOT a markdown table — reshape into `\| Link \| Description \|` rows |
| `[+]` | source has it, local doesn't — empty block will be added on `--apply` |
| `[orphan]` | local has it, source doesn't — kept verbatim. Decide: keep (intentional extension), remove (stale), or **relocate** — when the same tag shows `[+]` on another file, the framework moved its host (e.g. `components`/`root` from `index.md` to `domain.md`); migrate the body and delete the orphan block. The `llm-update` skill carries the recipe. |

#### 3. Prose (everything else)

**Taken FROM SOURCE by default** — this is where framework updates land (new rules, refined explanations, documentation tweaks). `--keep-prose` opts out per invocation with a per-file warning that the tree may diverge from its spec.

### Skills and slash commands (deterministic)

Skills and slash commands are **framework-owned artifacts**, sourced from the flavor (`frameworks/<flavor>/skills/` and `frameworks/<flavor>/commands/`). Universal items (`llm-doctor`, `llm-install`, `llm-update` + `/llm:doctor`, `/llm:update`, `/llm:resolve`) live in `__base/` and are mirrored verbatim into every flavor (drift-checked at install-script time), so sourcing only from the flavor is always complete.

On `--apply`:
- Every `<source>/frameworks/<flavor>/skills/llm-*/` is copied to the detected installed agent skill dirs (`<parent>/.claude/skills/<name>/`, `<parent>/.codex/skills/<name>/`, or both). Opt-ins (non-`llm-*` skills the adopter installed via `--with`) are NOT touched — they become adopter-owned after install.
- Every `<source>/frameworks/<flavor>/commands/llm/<name>.md` is copied to the detected installed agent command dirs (`<parent>/.claude/commands/llm/<name>.md`, `<parent>/.codex/commands/llm/<name>.md`, or both).
- Installed agent `skills/llm-*/` dirs absent from the source are pruned (deprecated cleanup).
- Installed agent `commands/llm/*.md` files absent from the source are reported as deprecated — listed with a warning, but NOT deleted (review manually).
- If the adopter still has a legacy `<target>/skills/` dir (pre-current layout), it is removed.

The general dry-run (without `--apply`) does **not** preview skills/commands changes — they are deterministic and need no per-item review. Use the dedicated `skills` or `commands` target to list what that artifact-only update would install.

## Dedicated targets

### `llm update skills`

Without `--apply`, lists the framework-owned `llm-*` skills that would be installed and reports a legacy `.llm/skills/` directory if present. With `--apply`, replaces installed framework skills, prunes deprecated `llm-*` skill mirrors, and removes the legacy directory. It does not touch `.llm/` files or slash commands.

### `llm update commands`

Without `--apply`, lists the slash commands that would be installed. With `--apply`, replaces framework slash commands and reports deprecated local commands for manual review. It does not touch `.llm/` files or skills.

### `llm update schema`

The general update deliberately excludes `schema.yaml` because it mixes framework contracts with adopter-owned regions such as `meta.apps.values` and locally added pillars.

Without `--apply`, this target prints a raw source-versus-local diff and identifies adopter-owned regions to preserve during a hand merge. This is the recommended schema reconciliation path.

With `--apply`, it replaces the local schema wholesale. This is intentionally destructive and loses adopter customizations; use it only when a brute overwrite is explicitly desired.

## Version drift

Update compares `version:` in the source `schema.yaml` against `framework-version:` in `.llm/index.md`. **Mismatch = MIGRATION** — the command reports the drift and points at the migration procedure, but it does not block the update. Dry-run remains a review; `--apply` applies the requested update so migration work can proceed.

## File-presence triage

| Case | Action |
|---|---|
| **Source-only** (framework added a file) | Whole-copy on `--apply` |
| **Local-only** (adopter-created entity, e.g. `intake/JET-X/`, `plans/<ID>/`) | Never touched |
| **Both sides** (framework-shipped + present locally) | Per-file three-region model |

Passing an adopter-owned path as `<path>` is rejected with "no framework source exists for this path".

## Dry-run output (default)

For each `.llm/` file that needs attention, prints:
- Frontmatter key drift (source-only, local-only).
- Tag analysis (`[=]` / `[?]` / `[Δ]` / `[+]` / `[orphan]` — see "Tag bodies" above).
- Unified diff of local → what `--apply` would produce.

Summary line lists each changed file as `[merge]` or `[new]`, plus a note that skills/commands will be replaced on `--apply`.

## `--apply` path

Performs the full update:
1. `.llm/` file merge: prose from source, frontmatter + bodies preserved, missing markers added empty.
2. Skills replace: every `frameworks/<flavor>/skills/llm-*/` overwritten in detected installed agent skill dirs; deprecated `llm-*` mirrors pruned; legacy `<target>/skills/` removed.
3. Commands replace: every `frameworks/<flavor>/commands/llm/*.md` overwritten in detected installed agent command dirs; deprecated commands listed.

## What it does NOT do

Updates to the `llm` script itself and `src/*.sh` are **not** this command's responsibility — they live outside `.llm/`. For those, run [`llm upgrade`](upgrade.md), which re-runs the install script (replaces `~/.dot-llm` wholesale on every run).

## Examples

```bash
llm update                                                     # dry-run from active checkout
llm update --apply                                             # apply merge + replace skills/commands
llm update templates                                           # scope .llm/ review to a dir
llm update intake/index.md                                     # scope to one file
llm update --keep-prose --apply                                # apply but keep local prose
llm update --from /path/to/dot-llm                             # source from a local checkout
llm update --from https://github.com/rntgspr/dot-llm.git       # source from git
llm update skills                                               # list framework skills to install
llm update skills --apply                                       # replace only framework skills
llm update commands --apply                                     # replace only slash commands
llm update schema                                               # review schema diff for hand merge
llm update schema --apply                                       # destructively replace local schema
```

## Related

- [`llm tag`](tag.md) — used to round-trip table bodies when reshaping is needed.
- [`llm doctor`](doctor.md) — run after update to verify the merged tree.
- `/llm:update` slash command — orchestrates update + per-file review + confirmation before `--apply`.
