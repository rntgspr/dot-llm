# `llm uninstall`

Reverse of [`llm install`](install.md). Removes `.llm/`, strips installed agent hook blocks (`CLAUDE.md` and/or `AGENTS.md`), removes project `UserPromptSubmit` context hooks, and removes installed framework slash commands and skills. Refuses non-interactive (no TTY) unless `--yes` is passed.

## Usage

```
llm uninstall [--yes]
```

| Flag | Description |
|---|---|---|
| `--yes`, `-y` | Skip the confirmation prompt. Required for non-TTY runs (CI, scripts, agents). |

## What it does

1. **Pre-checks**:
   - If `.llm/` exists, it must look like an install (`index.md` + `schema.yaml` at its root).
   - If `--yes` is not set and stdin is not a TTY, refuses with a hint to pass `--yes`.
2. **Confirmation** (TTY without `--yes`):
   - Prints the target path + what will be removed + the agent instruction-file changes.
   - Reads `y/N` from stdin; aborts on anything else.
3. **Removes the install tree** — `rm -rf .llm/`.
4. **Strips context hooks** — removes only the `UserPromptSubmit` command hook pointing at `.llm/hooks/context-loader.sh` from `.claude/settings.json` and/or `.codex/hooks.json`, using `jq`. Other hooks and settings remain untouched.
5. **Strips agent instruction hooks** — locates the `<!-- BEGIN DOT-LLM-HOOK --> ... <!-- END DOT-LLM-HOOK -->` block in the parent's `CLAUDE.md` and/or `AGENTS.md` and removes it (along with surrounding blank lines). If install created the file and only its boilerplate remains, removes it too.
6. **Removes the framework commands namespace** — the entire `.claude/commands/llm/` and/or `.codex/commands/llm/` directory. The `llm` subdir is the framework namespace; every `.md` inside is framework-owned. Adopter-authored commands at other paths or namespaces are not touched.
7. **Removes the framework skills** — every `.claude/skills/llm-*/` and/or `.codex/skills/llm-*/` directory. The `llm-` prefix is the framework namespace marker. Opt-ins (any skill without the `llm-` prefix) and adopter-authored skills are not touched. After removal, empty agent dirs are pruned.
8. **Prints a summary** of what was removed.

## When to use

- Resetting a bench between test cycles.
- Migrating to a different flavor (uninstall, then `llm install --framework <new>`).
- Removing the framework from a project that won't use it anymore.

**Don't use it to "refresh" the framework** — that's [`llm update`](update.md)'s job. Uninstall is destructive; update is steady-state.

## Examples

```bash
llm uninstall                       # interactive (TTY required)
llm uninstall --yes                 # non-interactive (CI / agents)
```

## Related

- [`llm install`](install.md) — installs the inverse.
- [`llm update`](update.md) — for upgrading an existing install, not removing it.
