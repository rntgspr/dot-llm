# cmd_install.sh — install a framework flavor into a project's .llm/.
#
# Each flavor is self-contained (its own schema + starter files):
#   --framework base                    → frameworks/__base/   (minimal kernel)
#   --framework sdlc-it-project-basic   → frameworks/sdlc-it-project-basic/   (default)
#   --framework <other>                 → frameworks/<other>/  (future flavors)
#
# Expects from the entry-point:
#   BASE_FRAMEWORK_SRC  — path to frameworks/__base/
#   FRAMEWORKS_DIR      — path to frameworks/
#   DEFAULT_FRAMEWORK   — default flavor name
#   _resolve_framework_src — function to resolve flavor name → source dir
#   SKILLS_SRC          — path to skills/ (opt-in skills sourced via --with)

cmd_install() {
  local target="$DOT_LLM_DIR"
  local with_skills=()
  local flavor="$DEFAULT_FRAMEWORK"
  local agent_target=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --framework)
        [[ -n "${2:-}" ]] || { red "✗ --framework requires a name (e.g. sdlc-it-project-basic, base)"; return 2; }
        flavor="$2"; shift 2 ;;
      --framework=*)
        flavor="${1#--framework=}"; shift ;;
      --with)
        [[ -n "${2:-}" ]] || { red "✗ --with requires a skill name (e.g. --with git)"; return 2; }
        with_skills+=("$2"); shift 2 ;;
      --with=*)
        with_skills+=("${1#--with=}"); shift ;;
      --agent)
        [[ -n "${2:-}" ]] || { red "✗ --agent requires one of: claude, codex, both"; return 2; }
        agent_target="$2"; shift 2 ;;
      --agent=*)
        agent_target="${1#--agent=}"; shift ;;
      -h|--help|help)
        cmd_install_help; return 0 ;;
      -*)
        red "unknown flag: $1"; cmd_install_help; return 2 ;;
      *)
        red "unexpected arg: $1"; cmd_install_help; return 2 ;;
    esac
  done

  if [[ -z "$agent_target" ]]; then
    if [[ -t 0 ]]; then
      agent_target=$(_install_prompt_agent_target) || return 2
    else
      agent_target="claude"
      yellow "⚠ --agent not provided in non-interactive install; defaulting to claude."
    fi
  fi
  _install_validate_agent_target "$agent_target" || return 2

  # Resolve flavor → source dir.
  local framework_src
  framework_src=$(_resolve_framework_src "$flavor") || return 1
  if [[ ! -d "$framework_src" ]]; then
    red "✗ framework not found at $framework_src"
    return 1
  fi

  if [[ -e "$target" ]]; then
    if [[ ! -t 0 ]]; then
      red "✗ target $target already exists (run interactively to confirm overwrite)"
      return 1
    fi
    local answer=""
    read -r -p "Target $target already exists. Overwrite? This will replace its contents. [y/N] " answer
    case "${answer:-N}" in
      [Yy]*) rm -rf "$target" ;;
      *)     red "✗ aborted; target $target left untouched"; return 1 ;;
    esac
  fi

  # Pre-validate skills before any write — fail fast.
  local skill src
  for skill in "${with_skills[@]+"${with_skills[@]}"}"; do
    src="$SKILLS_SRC/${skill}/SKILL.md"
    [[ -f "$src" ]] || { red "✗ skill not found: $skill (looked for $src)"; return 1; }
  done

  local parent
  parent=$(dirname "$target")
  mkdir -p "$parent"

  # Copy the chosen flavor wholesale, then drop the skills/ and commands/
  # subdirs — those are framework-owned artifacts that live exclusively under
  # the selected agent project dirs (.claude/ or .codex/). The cp -R is kept
  # (atomic, simpler than per-entry filtering); the
  # immediately-after rm -rf is the explicit declaration that neither
  # subdir belongs inside the adopter's .llm/ tree.
  cp -R "$framework_src" "$target"
  rm -rf "$target/skills" "$target/commands"
  green "✓ installed framework '$flavor' to $target"

  # Install framework skills (flavor-shipped llm-* + universal llm-* +
  # opt-ins) into each selected agent's project skill directory.
  _framework_install_skills_for_agents "$parent" "$framework_src" "0" "$agent_target" "${with_skills[@]+"${with_skills[@]}"}"

  # Wire the selected agent instruction files so the LLM auto-loads
  # .llm/index.md on every session.
  _install_wire_agent_hooks "$parent" "$agent_target"

  # Wire real prompt-submit hooks so each selected client refreshes relevant
  # .llm/ context on every prompt.
  _install_wire_context_hooks "$parent" "$agent_target"

  # Install slash commands into each selected agent's commands dir
  # (skip-if-exists).
  _framework_copy_commands_for_agents "$parent" "$framework_src" "0" "$agent_target"

  cat <<EOF

Next steps:
  1. Edit $target/domain.md — replace the placeholder components table with
     your project's actual components.
  2. Edit $target/schema.yaml — under meta.apps.values, list one entry per
     component your project ships. Keep platform and meta as reserved.
  3. Run health checks:
       llm doctor

The installed agent hook ensures each selected client in this repo loads
$target/index.md automatically and refreshes relevant .llm/ context on every
prompt. Open the project in your client and the framework is wired in.
EOF
}

# --- shared helpers (used by cmd_install and cmd_update) -------------------

# Install framework skills directly into an agent's project skill directory.
# Source: the flavor's own skills/ subdir — universals live in __base/skills/
# and are mirrored verbatim into every flavor (drift-checked at install-script
# time), so the flavor dir alone is complete.
# Opt-ins (--with) are sourced from $SKILLS_SRC (top-level skills/).
# Install (replace=0): skip-if-exists for llm-*, never clobber adopter
# skills with the same name. Update (replace=1): always overwrite llm-*;
# opt-ins are not touched (opt-ins are adopter-owned post-install — update
# never receives a with_skills list).
# Args: parent framework_src replace(0|1) agent(claude|codex) [with_skills...]
_framework_install_skills_to_agent() {
  local parent="$1" framework_src="$2" replace="$3" agent="$4"; shift 4
  local with_skills=("$@")
  local skills_dir
  skills_dir=$(_agent_skills_dir "$parent" "$agent") || return 2
  mkdir -p "$skills_dir"

  local skill_dir name dest
  if [[ -d "$framework_src/skills" ]]; then
    for skill_dir in "$framework_src/skills"/llm-*/; do
      [[ -d "$skill_dir" ]] || continue
      name=$(basename "${skill_dir%/}")
      dest="$skills_dir/$name"
      if [[ "$replace" == "0" && -e "$dest" ]]; then
        say "  · $(_agent_rel_path "$parent" "$dest") already present (skip)"
        continue
      fi
      rm -rf "$dest"
      cp -R "${skill_dir%/}" "$dest"
      [[ "$replace" == "1" ]] && green "  ↺ $(_agent_rel_path "$parent" "$dest")" || green "  + $(_agent_rel_path "$parent" "$dest")"
    done
  fi

  local skill
  for skill in "${with_skills[@]+"${with_skills[@]}"}"; do
    rm -rf "$skills_dir/$skill"
    cp -R "$SKILLS_SRC/$skill" "$skills_dir/"
    green "  + $(_agent_rel_path "$parent" "$skills_dir/$skill") (opt-in)"
  done
}

# Args: parent framework_src replace(0|1) agent_target [with_skills...]
_framework_install_skills_for_agents() {
  local parent="$1" framework_src="$2" replace="$3" agent_target="$4"; shift 4
  local agent
  for agent in $(_agent_target_list "$agent_target"); do
    say "Skills ($agent):"
    _framework_install_skills_to_agent "$parent" "$framework_src" "$replace" "$agent" "$@"
  done
}

# Backward-compatible wrapper for update paths that still target Claude only.
_framework_install_skills_to_claude() {
  local parent="$1" framework_src="$2" replace="$3"; shift 3
  _framework_install_skills_to_agent "$parent" "$framework_src" "$replace" "claude" "$@"
}

# Remove llm-* skill dirs in an agent's skills dir that no longer exist
# in the framework flavor source. Opt-ins (non-llm-* dirs) are never
# touched.
# Args: parent framework_src agent
_framework_prune_deprecated_llm_skills_for_agent() {
  local parent="$1" framework_src="$2" agent="$3"
  local skills_dir
  skills_dir=$(_agent_skills_dir "$parent" "$agent") || return 2
  [[ -d "$skills_dir" ]] || return 0
  local skill_dir name
  for skill_dir in "$skills_dir"/llm-*/; do
    [[ -d "$skill_dir" ]] || continue
    name=$(basename "${skill_dir%/}")
    [[ -d "$framework_src/skills/$name" ]] && continue
    rm -rf "$skill_dir"
    yellow "  - removed deprecated: $(_agent_rel_path "$parent" "$skill_dir")"
  done
}

# Args: parent framework_src agent_target
_framework_prune_deprecated_llm_skills_for_agents() {
  local parent="$1" framework_src="$2" agent_target="$3"
  local agent
  for agent in $(_agent_target_list "$agent_target"); do
    _framework_prune_deprecated_llm_skills_for_agent "$parent" "$framework_src" "$agent"
  done
}

_framework_prune_deprecated_llm_skills() {
  local parent="$1" framework_src="$2"
  _framework_prune_deprecated_llm_skills_for_agent "$parent" "$framework_src" "claude"
}

# Drop the legacy <target>/skills/ subdir if a prior install (pre-current
# layout) created one. Skills do not live inside .llm/ anymore — they live
# exclusively under an agent's project skills dir. Called by update to migrate
# adopters off the old layout.
# Args: target
_framework_prune_legacy_dot_llm_skills() {
  local target="$1"
  [[ -d "$target/skills" ]] || return 0
  rm -rf "$target/skills"
  yellow "  - removed legacy: $target/skills (skills now live in agent project skill dirs)"
}

# Copy slash commands from $framework_src/commands/ into
# an agent's commands dir. Walks recursively so subdirs (namespaces) are
# preserved. Universal commands live in __base/commands/ and are mirrored
# verbatim into every flavor (drift-checked at install-script time), so
# the flavor dir alone is complete.
# For install (replace=0): skip-if-exists per file.
# For update (replace=1): always overwrites.
# Args: parent framework_src replace(0|1) agent
_framework_copy_commands_to_agent() {
  local parent="$1" framework_src="$2" replace="$3" agent="$4"
  local cmds_src="$framework_src/commands"
  [[ -d "$cmds_src" ]] || return 0

  local cmd_files=() cmd_file
  while IFS= read -r -d '' cmd_file; do
    cmd_files+=("$cmd_file")
  done < <(find "$cmds_src" -type f -name '*.md' -print0)
  [[ ${#cmd_files[@]} -eq 0 ]] && return 0

  local cmds_dir
  cmds_dir=$(_agent_commands_dir "$parent" "$agent") || return 2
  mkdir -p "$cmds_dir"

  local rel dest slash
  for cmd_file in "${cmd_files[@]}"; do
    rel="${cmd_file#"$cmds_src"/}"
    dest="$cmds_dir/$rel"
    slash="${rel%.md}"
    slash="/${slash//\//:}"
    if [[ "$replace" == "0" && -f "$dest" ]]; then
      say "  · ${slash} already present (skip)"
    else
      mkdir -p "$(dirname "$dest")"
      cp "$cmd_file" "$dest"
      [[ "$replace" == "1" ]] && green "  ↺ ${slash}" || green "  + ${slash}"
    fi
  done
}

# Args: parent framework_src replace(0|1) agent_target
_framework_copy_commands_for_agents() {
  local parent="$1" framework_src="$2" replace="$3" agent_target="$4"
  local agent
  for agent in $(_agent_target_list "$agent_target"); do
    say "Slash commands ($agent):"
    _framework_copy_commands_to_agent "$parent" "$framework_src" "$replace" "$agent"
  done
}

_framework_copy_commands() {
  local parent="$1" framework_src="$2" replace="$3"
  _framework_copy_commands_to_agent "$parent" "$framework_src" "$replace" "claude"
}

# List llm-* commands under an agent's commands dir that no longer
# exist in the framework flavor source. Prints one rel path per line.
# Args: parent framework_src agent
_framework_deprecated_commands_for_agent() {
  local parent="$1" framework_src="$2" agent="$3"
  local cmds_dir
  cmds_dir=$(_agent_commands_dir "$parent" "$agent") || return 2
  local cmds_src="$framework_src/commands"
  [[ -d "$cmds_dir" ]] || return 0
  [[ -d "$cmds_src" ]] || return 0
  local file rel
  while IFS= read -r -d '' file; do
    rel="${file#"$cmds_dir"/}"
    [[ -f "$cmds_src/$rel" ]] || echo "$rel"
  done < <(find "$cmds_dir" -type f -name '*.md' -print0)
}

_framework_deprecated_commands() {
  local parent="$1" framework_src="$2"
  _framework_deprecated_commands_for_agent "$parent" "$framework_src" "claude"
}

# --- install-private helpers ------------------------------------------------

_install_validate_agent_target() {
  case "$1" in
    claude|codex|both) return 0 ;;
    *) red "✗ invalid --agent '$1' (expected: claude, codex, both)"; return 2 ;;
  esac
}

_install_prompt_agent_target() {
  local answer=""
  cat >&2 <<'EOF'
Which agent client should this repo be wired for?
  1) claude
  2) codex
  3) both
EOF
  read -r -p "Choose [1/2/3, default: 1] " answer
  case "${answer:-1}" in
    1|claude|Claude|CLAUDE) printf '%s\n' "claude" ;;
    2|codex|Codex|CODEX)    printf '%s\n' "codex" ;;
    3|both|Both|BOTH)       printf '%s\n' "both" ;;
    *) red "✗ invalid agent choice: $answer"; return 2 ;;
  esac
}

_agent_target_list() {
  case "$1" in
    claude) printf '%s\n' "claude" ;;
    codex)  printf '%s\n' "codex" ;;
    both)   printf '%s\n%s\n' "claude" "codex" ;;
    *)      return 2 ;;
  esac
}

_agent_instruction_file() {
  local parent="$1" agent="$2"
  case "$agent" in
    claude) printf '%s\n' "$parent/CLAUDE.md" ;;
    codex)  printf '%s\n' "$parent/AGENTS.md" ;;
    *)      return 2 ;;
  esac
}

_agent_skills_dir() {
  local parent="$1" agent="$2"
  case "$agent" in
    claude) printf '%s\n' "$parent/.claude/skills" ;;
    codex)  printf '%s\n' "$parent/.codex/skills" ;;
    *)      return 2 ;;
  esac
}

_agent_commands_dir() {
  local parent="$1" agent="$2"
  case "$agent" in
    claude) printf '%s\n' "$parent/.claude/commands" ;;
    codex)  printf '%s\n' "$parent/.codex/commands" ;;
    *)      return 2 ;;
  esac
}

_agent_hook_config_file() {
  local parent="$1" agent="$2"
  case "$agent" in
    claude) printf '%s\n' "$parent/.claude/settings.json" ;;
    codex)  printf '%s\n' "$parent/.codex/hooks.json" ;;
    *)      return 2 ;;
  esac
}

_agent_rel_path() {
  local parent="$1" path="$2"
  printf '%s\n' "${path#"$parent"/}"
}

# Print the dot-llm hook block to stdout.
# Args: rel_index (e.g. ".llm/index.md"); created (1 if install is creating the
# instruction file fresh, 0/absent if appending to a pre-existing file). The `created`
# flag in the BEGIN marker is the provenance signal uninstall uses to decide
# whether it may delete the whole file or must only strip the block.
_install_print_hook_block() {
  local rel_index="$1" created="${2:-0}" agent="${3:-agent}"
  local begin="<!-- BEGIN DOT-LLM-HOOK -->"
  [[ "$created" == "1" ]] && begin="<!-- BEGIN DOT-LLM-HOOK created -->"
  cat <<EOF
$begin
## \`.llm/\` framework

This project uses the \`.llm/\` framework — a spec-driven, agent-friendly knowledge structure. Whenever you start a $agent session in this repository, **read \`$rel_index\` first**. It carries the schema, the pillars declared for this project, the loading rule for what enters context, and any role definitions present under \`$rel_index\`'s siblings.

@$rel_index
<!-- END DOT-LLM-HOOK -->
EOF
}

_install_wire_agent_hook() {
  local parent="$1" agent="$2"
  local instructions
  instructions=$(_agent_instruction_file "$parent" "$agent") || return 2
  local rel_index="$DOT_LLM_DIR/index.md"

  if [[ -f "$instructions" ]]; then
    if grep -q "BEGIN DOT-LLM-HOOK" "$instructions"; then
      say "  · $(_agent_rel_path "$parent" "$instructions") hook already present (skip)"
      return 0
    fi
    {
      echo ""
      _install_print_hook_block "$rel_index" "0" "$agent"
    } >> "$instructions"
    green "  + $(_agent_rel_path "$parent" "$instructions") hook appended at $instructions"
  else
    {
      echo "# Project instructions"
      echo ""
      _install_print_hook_block "$rel_index" "1" "$agent"
    } > "$instructions"
    green "  + $(_agent_rel_path "$parent" "$instructions") created at $instructions (with .llm/ hook)"
  fi
}

_install_wire_agent_hooks() {
  local parent="$1" agent_target="$2"
  local agent
  for agent in $(_agent_target_list "$agent_target"); do
    _install_wire_agent_hook "$parent" "$agent"
  done
}

_install_wire_context_hook() {
  local parent="$1" agent="$2"
  local config_file
  config_file=$(_agent_hook_config_file "$parent" "$agent") || return 2
  local hook_script="$parent/.llm/hooks/context-loader.sh"
  local command="DOT_LLM_HOOK_TARGET=$agent bash \"$hook_script\" --target=$agent"

  if [[ ! -f "$hook_script" ]]; then
    yellow "  · .llm/hooks/context-loader.sh not present; context hook skipped for $agent"
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    red "✗ jq is required to wire $agent context hooks"
    return 1
  fi

  mkdir -p "$(dirname "$config_file")"
  [[ -f "$config_file" ]] || printf '{}\n' > "$config_file"

  local existed=0
  if jq -e --arg command "$command" '
    any(.hooks.UserPromptSubmit[]?; any(.hooks[]?; .type == "command" and .command == $command))
  ' "$config_file" >/dev/null 2>&1; then
    existed=1
  fi

  local tmp
  tmp=$(mktemp)
  jq --arg command "$command" '
    .hooks //= {} |
    .hooks.UserPromptSubmit //= [] |
    if any(.hooks.UserPromptSubmit[]?; any(.hooks[]?; .type == "command" and .command == $command)) then
      .
    else
      .hooks.UserPromptSubmit += [{
        hooks: [{
          type: "command",
          command: $command,
          timeout: 10,
          statusMessage: "Refreshing .llm context"
        }]
      }]
    end
  ' "$config_file" > "$tmp" && mv "$tmp" "$config_file"

  local result
  [[ "$existed" == "1" ]] && result="present" || result="added"
  if grep -Fq "$hook_script" "$config_file"; then
    [[ "$result" == "present" ]] && say "  · $(_agent_rel_path "$parent" "$config_file") context hook already present (skip)" || green "  + $(_agent_rel_path "$parent" "$config_file") context hook wired"
  else
    red "✗ failed to wire context hook in $config_file"
    return 1
  fi
}

_install_wire_context_hooks() {
  local parent="$1" agent_target="$2"
  local agent
  for agent in $(_agent_target_list "$agent_target"); do
    _install_wire_context_hook "$parent" "$agent"
  done
}

_install_wire_claude_md() {
  local parent="$1"
  _install_wire_agent_hook "$parent" "claude"
}

# List available framework flavors (one per line): "<name>\t<one-line summary>".
_install_list_frameworks() {
  printf '%s\t%s\n' "base" "minimal kernel — rules + meta, no pillars."
  if [[ -d "$FRAMEWORKS_DIR" ]]; then
    local d name
    for d in "$FRAMEWORKS_DIR"/*/; do
      [[ -d "$d" ]] || continue
      name=$(basename "$d")
      [[ "$name" == __* ]] && continue
      # Summary comes from the flavor's domain.md H1 — NOT index.md, which is the
      # universal kernel (byte-identical across flavors) and would yield the same
      # generic line for every flavor. domain.md carries the flavor's identity.
      local summary=""
      if [[ -f "$d/domain.md" ]]; then
        summary=$(awk '/^# / { sub(/^# /, ""); print; exit }' "$d/domain.md")
      fi
      [[ -z "$summary" ]] && summary="framework flavor"
      [[ ${#summary} -gt 70 ]] && summary="${summary:0:67}..."
      printf '%s\t%s\n' "$name" "$summary"
    done
  fi
}

# List opt-in skills (non-llm-*) for the --with flag.
_install_list_skills() {
  [[ -d "$SKILLS_SRC" ]] || return 0
  local d name desc
  for d in "$SKILLS_SRC"/*/; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    [[ "$name" == llm-* ]] && continue
    [[ -f "$d/SKILL.md" ]] || continue
    desc=$(awk '
      /^---$/ { c++; if (c==2) exit; next }
      c==1 && /^description:/ {
        line=$0
        sub(/^description:[[:space:]]*[>|]?[+-]?[[:space:]]*/, "", line)
        if (length(line) > 0) acc = line
        in_desc = 1
        next
      }
      c==1 && in_desc && /^[[:space:]]+[^[:space:]]/ {
        line=$0; sub(/^[[:space:]]+/, "", line)
        acc = (acc == "" ? line : acc " " line)
        next
      }
      c==1 && in_desc && /^[a-zA-Z]/ { in_desc = 0 }
      END { print acc }
    ' "$d/SKILL.md")
    [[ ${#desc} -gt 70 ]] && desc="${desc:0:67}..."
    printf '%s\t%s\n' "$name" "${desc:-(no description)}"
  done
}

cmd_install_help() {
  cat <<'EOF'
llm install — install a framework flavor into a project's .llm/

Usage:
  llm install [--framework <name>] [--agent <claude|codex|both>] [--with <skill>...]

Options:
  --framework <name>     which flavor to install. Default: sdlc-it-project-basic.
                         Available (discovered from frameworks/, including __base/):
EOF
  _install_list_frameworks | awk -F'\t' '{ printf "                           %-26s %s\n", $1, $2 }'
  cat <<'EOF'
  --with <skill>         include an opt-in skill (looked up in skills/<skill>/SKILL.md
                         in the dot-llm checkout). Repeatable.
                         Available (discovered from skills/; `llm-*` skills are
                         auto-installed and don't need --with):
EOF
  _install_list_skills | awk -F'\t' '{ printf "                           %-26s %s\n", $1, $2 }'
  cat <<'EOF'
  --agent <target>       wire project hooks, skills, and commands for claude,
                         codex, or both. If omitted interactively, install asks.
                         If omitted non-interactively, defaults to claude.
EOF
  cat <<EOF

Auto-installed skills (shipped by every flavor; sourced from frameworks/__base/skills/):
EOF
  for d in "$BASE_FRAMEWORK_SRC"/skills/llm-*/; do
    [[ -d "$d" ]] || continue
    printf '  %s\n' "$(basename "$d")"
  done
  cat <<'EOF'

Examples:
  llm install                                       # default flavor at .llm/
  llm install --agent codex                         # Codex hook + .codex assets
  llm install --agent both --with git               # Claude and Codex assets
  llm install --framework base                      # minimal kernel only
  llm install --with git                            # default flavor + git skill
  llm install --framework sdlc-it-project-basic --with git
EOF
}
