---
name: install-sh-destructive
description: Never run install.sh (or llm upgrade) without explicit user request — it rm -rf ~/.dot-llm and breaks the workspace symlink
metadata:
  type: feedback
---

Do not invoke `src/install.sh` (directly via `bash src/install.sh` or indirectly via `llm upgrade`) without an explicit request from the user.

**Why:** The script begins with `rm -rf "$DEST"` (where `$DEST=~/.dot-llm`). On 2026-06-10 I ran it while only intending to validate the kernel-drift check; the `rm -rf` destroyed the `~/.dot-llm → ~/workspace/dot-llm` symlink we had just set up. macOS happened to remove only the link itself (not follow into the workspace), but on other systems the same operation could obliterate the workspace, including `.git`. The user had told me earlier that local execution of `install.sh` / `llm upgrade` was implausible from this machine — the run violated that scope.

**How to apply:**
- Validating kernel-drift integrity does NOT require running `install.sh`. The check is just `cmp -s` over `frameworks/__base/{index.md,skills,commands}` against each flavor's mirror — run that loop directly.
- If `install.sh` truly needs to run (refresh the `~/.dot-llm` snapshot from `origin/main`, etc.), confirm with the user first and warn that the workspace symlink will be lost and must be re-created.
- `llm upgrade` delegates to `install.sh`; the same rule applies.
- Related: [[symlink-dot-llm-to-workspace]] — the live link we use instead of a snapshot.
