# `llm upgrade`

Update the `llm` tool itself. Does **nothing beyond re-running the install script**: wipes `~/.dot-llm`, fresh shallow clone, strips `.git/`, re-links `~/.local/bin/llm`.

```
llm upgrade
```

Equivalent to the install one-liner: `curl -fsSL https://pixelpunk.works/dot-llm/install.sh | bash`.

## Kernel integrity check

The install script verifies the downloaded snapshot before linking: every `frameworks/<flavor>/index.md` must be **byte-identical** to `frameworks/__base/index.md` (the universal kernel — see [architecture](architecture.md)). On any divergence the install aborts with `✗ kernel drift` — the snapshot is a broken distribution, not something the adopter can fix locally.

This check belongs here, not in `llm doctor`: doctor audits the **adopter's** `.llm/` tree, which never contains `__base` to compare against. Kernel drift is a distribution problem, caught at the point where the snapshot lands on disk.

## Scope

| Concern | Command |
|---|---|
| The tool (`llm`, `src/*.sh`, `frameworks/`, `skills/`, `commands/` in `~/.dot-llm`) | `llm upgrade` |
| An installed project tree (`.llm/`, its skills, slash commands) | [`llm update`](update.md) |

`upgrade` never touches any project's `.llm/`. After upgrading, run `llm update` per project to pull the new framework content in.

## Related

- [`llm update`](update.md) — steady-state update of an installed `.llm/` tree.
- [architecture](architecture.md) — why the kernel must be byte-identical across flavors.
