# cmd_uninstall.sh — reverse `llm install` for a project.
#
# Removes only what `llm install` creates, in reverse order:
#   1. <parent>/{.claude,.codex}/commands/llm/ — the entire dir. The `llm` subdir
#      is the framework namespace; everything inside is ours. Adopter-
#      authored commands at other paths (or other namespaces) are not
#      touched.
#   2. every <parent>/{.claude,.codex}/skills/llm-*/ — the `llm-` prefix is the
#      skill namespace marker; same ownership rule.
#   3. the UserPromptSubmit context hook in <parent>/{.claude/settings.json,
#      .codex/hooks.json}.
#   4. the <!-- BEGIN/END DOT-LLM-HOOK --> block in <parent>/CLAUDE.md and
#      <parent>/AGENTS.md, plus
#      the single blank line install inserted before it. The file is removed
#      entirely when nothing but the install-created header remains.
#   5. the <target> tree (.llm/).
#
# Destructive: prompts before acting. Pass --yes for non-interactive runs
# (an agent or CI has no TTY; without --yes and without a TTY it refuses).
# Idempotent: a second run is a silent no-op.

cmd_uninstall() {
  local target="$DOT_LLM_DIR" assume_yes=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)        assume_yes=1; shift ;;
      -h|--help|help)  cmd_uninstall_help; return 0 ;;
      -*)              red "unknown flag: $1"; cmd_uninstall_help; return 2 ;;
      *)
        red "unexpected arg: $1"; cmd_uninstall_help; return 2 ;;
    esac
  done
  local parent claude_md agents_md claude_settings codex_hooks
  parent=$(dirname "$target")
  claude_md="$parent/CLAUDE.md"
  agents_md="$parent/AGENTS.md"
  claude_settings="$parent/.claude/settings.json"
  codex_hooks="$parent/.codex/hooks.json"

  # --- discover what exists to remove ---
  local has_target=0 has_claude_hook=0 has_codex_hook=0 has_claude_context_hook=0 has_codex_context_hook=0
  [[ -d "$target" ]] && has_target=1
  [[ -f "$claude_md" ]] && grep -q "BEGIN DOT-LLM-HOOK" "$claude_md" && has_claude_hook=1
  [[ -f "$agents_md" ]] && grep -q "BEGIN DOT-LLM-HOOK" "$agents_md" && has_codex_hook=1
  [[ -f "$claude_settings" ]] && grep -q ".llm/hooks/context-loader." "$claude_settings" && has_claude_context_hook=1
  [[ -f "$codex_hooks" ]] && grep -q ".llm/hooks/context-loader." "$codex_hooks" && has_codex_context_hook=1

  # Validate an existing tree before removing any part of the install footprint.
  # Residual hooks, commands, and skills may still be cleaned when the tree is
  # already absent.
  local target_abs=""
  if [[ $has_target -eq 1 ]]; then
    target_abs="$(cd "$target" 2>/dev/null && pwd)" || target_abs=""
    if [[ -z "$target_abs" || "$target_abs" == "/" || "$target_abs" == "$HOME" || \
          ! -f "$target/index.md" || ! -f "$target/schema.yaml" ]]; then
      red "✗ refusing to uninstall — $target is not a dot-llm install (expected index.md + schema.yaml)"
      return 1
    fi
  fi

  # Framework-owned namespaces: <parent>/{.claude,.codex}/commands/llm/ and
  # every <parent>/{.claude,.codex}/skills/llm-*/ — the `llm` subdir for
  # commands and the `llm-` prefix for skills mark these as ours. Wipe them directly.
  # Anything outside (adopter-authored commands at other paths, opt-ins
  # under agent skill dirs) is never touched.
  local removable_cmd_dirs=()
  [[ -d "$parent/.claude/commands/llm" ]] && removable_cmd_dirs+=("$parent/.claude/commands/llm")
  [[ -d "$parent/.codex/commands/llm" ]] && removable_cmd_dirs+=("$parent/.codex/commands/llm")

  local removable_skill_dirs=()
  local skill_dir
  for skill_dir in "$parent/.claude/skills"/llm-*/ "$parent/.codex/skills"/llm-*/; do
    [[ -d "$skill_dir" ]] || continue
    removable_skill_dirs+=("${skill_dir%/}")
  done

  if [[ $has_target -eq 0 && $has_claude_hook -eq 0 && $has_codex_hook -eq 0 && $has_claude_context_hook -eq 0 && $has_codex_context_hook -eq 0 && ${#removable_cmd_dirs[@]} -eq 0 && ${#removable_skill_dirs[@]} -eq 0 ]]; then
    say "Nothing to uninstall — no .llm tree, no agent hook, no install-managed commands or skills at $parent."
    return 0
  fi

  # --- summary ---
  echo "llm uninstall will remove:"
  [[ $has_target -eq 1 ]] && echo "  - directory: $target"
  [[ $has_claude_hook -eq 1 ]] && echo "  - DOT-LLM-HOOK block in: $claude_md"
  [[ $has_codex_hook  -eq 1 ]] && echo "  - DOT-LLM-HOOK block in: $agents_md"
  [[ $has_claude_context_hook -eq 1 ]] && echo "  - context hook in: $claude_settings"
  [[ $has_codex_context_hook -eq 1 ]] && echo "  - context hook in: $codex_hooks"
  local d
  for d in "${removable_cmd_dirs[@]+"${removable_cmd_dirs[@]}"}"; do echo "  - commands: $d/"; done
  for d in "${removable_skill_dirs[@]+"${removable_skill_dirs[@]}"}"; do echo "  - skill: $d"; done

  # --- confirm ---
  if [[ $assume_yes -ne 1 ]]; then
    if [[ ! -t 0 ]]; then
      red "✗ refusing to uninstall non-interactively; pass --yes to confirm"
      return 1
    fi
    local answer=""
    read -r -p "Proceed? This cannot be undone. [y/N] " answer
    case "${answer:-N}" in
      [Yy]*) ;;
      *) red "✗ aborted; nothing was removed"; return 1 ;;
    esac
  fi

  # --- act (reverse order of install) ---
  for d in "${removable_cmd_dirs[@]+"${removable_cmd_dirs[@]}"}"; do
    rm -rf "$d" && green "  - removed commands: $d/"
  done
  for d in "${removable_skill_dirs[@]+"${removable_skill_dirs[@]}"}"; do
    rm -rf "$d" && green "  - removed skill: $d"
  done
  if [[ $has_claude_context_hook -eq 1 ]]; then
    _uninstall_strip_context_hook "$claude_settings"
  fi
  if [[ $has_codex_context_hook -eq 1 ]]; then
    _uninstall_strip_context_hook "$codex_hooks"
  fi
  _uninstall_prune_dirs "$parent/.claude"
  _uninstall_prune_dirs "$parent/.codex"

  if [[ $has_claude_hook -eq 1 ]]; then
    _uninstall_strip_hook "$claude_md"
  fi
  if [[ $has_codex_hook -eq 1 ]]; then
    _uninstall_strip_hook "$agents_md"
  fi

  if [[ $has_target -eq 1 ]]; then
    rm -rf "$target_abs" && green "  - removed directory: $target"
  fi

  green "✓ uninstalled"
}

# Remove now-empty command namespace dirs, then <agent>/commands/ and <agent>/
# itself when empty. rmdir fails safe on non-empty dirs (other tooling kept).
_uninstall_prune_dirs() {
  local base="$1"
  [[ -d "$base" ]] || return 0
  if [[ -d "$base/commands" ]]; then
    rmdir "$base/commands" 2>/dev/null || true
  fi
  if [[ -d "$base/skills" ]]; then
    rmdir "$base/skills" 2>/dev/null || true
  fi
  rmdir "$base" 2>/dev/null || true
}

# Strip the DOT-LLM-HOOK block (and the blank line install put before it) from
# CLAUDE.md. If only install-created boilerplate remains (empty, or just the
# "# Project instructions" header), remove the file entirely.
_uninstall_strip_hook() {
  local file="$1"
  local tmp
  tmp=$(mktemp)
  awk '
    { lines[NR] = $0 }
    END {
      b = 0; e = 0
      for (i = 1; i <= NR; i++) {
        if (lines[i] ~ /BEGIN DOT-LLM-HOOK/) b = i
        if (lines[i] ~ /END DOT-LLM-HOOK/)   e = i
      }
      if (b == 0 || e == 0) { for (i = 1; i <= NR; i++) print lines[i]; exit }
      drop = (b > 1 && lines[b-1] ~ /^[[:space:]]*$/) ? b - 1 : 0
      for (i = 1; i <= NR; i++) {
        if (i >= b && i <= e) continue
        if (i == drop)        continue
        print lines[i]
      }
    }
  ' "$file" > "$tmp"

  # Provenance: only delete the whole file when install CREATED it (the BEGIN
  # marker carries the `created` flag). If install merely APPENDED our block to
  # a pre-existing file, never delete it — strip the block and keep the rest,
  # even if what remains is empty or just a "# Project instructions" header,
  # because that content is the user's, not ours. (Hooks written before the
  # `created` flag existed are treated as appended → the safe, never-delete
  # side.)
  local created=0
  grep -q "BEGIN DOT-LLM-HOOK created" "$file" 2>/dev/null && created=1
  local stripped
  stripped=$(grep -v '^[[:space:]]*$' "$tmp" 2>/dev/null || true)
  if [[ $created -eq 1 && ( -z "$stripped" || "$stripped" == "# Project instructions" ) ]]; then
    rm -f "$file" "$tmp"
    green "  - removed CLAUDE.md (install-created, only our content remained): $file"
  else
    mv "$tmp" "$file"
    green "  - removed DOT-LLM-HOOK block from: $file"
  fi
}

# Remove only the install-managed UserPromptSubmit command that points to the
# project .llm context loader. Other hooks and settings remain untouched.
_uninstall_strip_context_hook() {
  local file="$1"
  command -v jq >/dev/null 2>&1 || { red "✗ jq is required to remove context hook from $file"; return 1; }
  local tmp
  tmp=$(mktemp)
  jq '
    if .hooks.UserPromptSubmit then
      .hooks.UserPromptSubmit |= (
        map(
          .hooks = ((.hooks // []) | map(select((.command // "" | contains(".llm/hooks/context-loader.")) | not)))
        )
        | map(select((.hooks // []) | length > 0))
      )
    else
      .
    end |
    if (.hooks.UserPromptSubmit? // [] | length) == 0 then
      del(.hooks.UserPromptSubmit)
    else
      .
    end |
    if (.hooks? // {} | length) == 0 then
      del(.hooks)
    else
      .
    end
  ' "$file" > "$tmp"

  if [[ "$(jq 'length' "$tmp")" == "0" ]]; then
    rm -f "$file" "$tmp"
  else
    mv "$tmp" "$file"
  fi
  green "  - removed context hook from: $file"
}

cmd_uninstall_help() {
  cat <<'EOF'
llm uninstall — reverse `llm install` for a project

Usage:
  llm uninstall [--yes]

Options:
  -y, --yes        skip the confirmation prompt (required for non-interactive
                   / agent / CI runs — without a TTY and without --yes it
                   refuses rather than guessing).

What it removes (only what `llm install` created):
  1. The whole .claude/commands/llm/ and .codex/commands/llm/ dirs. The
     `llm` subdir is the framework namespace — every command inside is ours.
     Adopter-authored commands at other paths are NEVER touched.
  2. Every .claude/skills/llm-*/ and .codex/skills/llm-*/ dir. The `llm-` prefix is the
     skill namespace marker; same ownership rule. Opt-ins (any skill
     without the `llm-` prefix) and adopter-authored skills are NEVER
     touched.
  3. The UserPromptSubmit context hook in .claude/settings.json and/or
     .codex/hooks.json when it points to .llm/hooks/context-loader.sh.
  4. The <!-- BEGIN/END DOT-LLM-HOOK --> block in CLAUDE.md and AGENTS.md (and the
     file itself if only install-created boilerplate remains).
  5. The .llm/ tree.

Idempotent: running it again when nothing is installed is a silent no-op.

Examples:
  llm uninstall                     # remove ./.llm + its install footprint
  llm uninstall --yes               # same, no prompt (agent/CI)
EOF
}
