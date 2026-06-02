# common.sh — shared helpers sourced by every cmd_*.sh module.
#
# Provides:
#   - colored output: red, yellow, green, say (gated by QUIET)
#   - frontmatter helpers for YAML-ish keys: fm_scalar, fm_list, fm_h1
#   - marker-block helpers for `<!-- llm:NAME -->` regions
#     (fm_block_list, fm_block_extract, fm_block_replace)
#
# The framework tree has one fixed project-relative location. Change it here
# only if every dot-llm project managed by this checkout must use another name.
DOT_LLM_DIR=".llm"
SCHEMA="$DOT_LLM_DIR/schema.yaml"
#
# Marker convention:
#   `<!-- llm:NAME -->` ... `<!-- /llm:NAME -->` where NAME is any string
#   matching `[a-z0-9_:-]+`. Single-token names (`intake`, `plans`,
#   `components`, `root`) are the canonical form for new tags. Two-token
#   names (`files:touched`, etc.) remain valid for pattern-based tags
#   declared in schema.yaml under `tags:`.

# --- color helpers ---

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
say()    { [[ "${QUIET:-0}" == "1" ]] || printf '%s\n' "$*"; }

# --- frontmatter scalar/list helpers ---

# Extract the scalar value of a top-level frontmatter key from $1. Empty if missing.
fm_scalar() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^---$/ { c++; if (c == 2) exit; next }
    c == 1 && $0 ~ "^"key":" {
      sub("^"key":[[:space:]]*", "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$file"
}

# Extract a YAML list under a top-level frontmatter key from $1. One item per line.
fm_list() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^---$/                                    { c++; if (c == 2) exit; next }
    c == 1 && $0 ~ "^"key":[[:space:]]*$"      { in_list = 1; next }
    in_list && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      sub(/[[:space:]]+#.*/, "")
      sub(/[[:space:]]+$/, "")
      print
      next
    }
    in_list && /^[a-zA-Z]/                     { exit }
  ' "$file"
}

# First H1 line in $1, with the leading `# ` stripped.
fm_h1() {
  awk '/^# / { sub(/^# /, ""); print; exit }' "$1"
}

# --- marker-block helpers ---

# Marker recognition is anchored to the **whole line** (with tolerance for
# leading whitespace and YAML/JS comment prefixes like `# ` or `// `). This
# prevents textual mentions of a marker inside prose (e.g. inline code in a
# rule explanation) from being treated as real boundaries.

# List every marker NAME present in $1 (one per line, sorted unique). NAME is
# whatever sits between `<!-- llm:` and ` -->`; may contain `:` for two-token
# tags (e.g. `files:touched`).
fm_block_list() {
  local file="$1"
  awk '
    {
      line = $0
      sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", line)
      sub(/[[:space:]]+$/, "", line)
    }
    line ~ /^<!-- llm:[a-z0-9_:-]+ -->$/ {
      m = line
      sub(/^<!-- llm:/, "", m)
      sub(/ -->$/, "", m)
      print m
    }
  ' "$file" | sort -u
}

# Print the body between `<!-- llm:NAME -->` and `<!-- /llm:NAME -->` in $1.
# Args: file, name.
fm_block_extract() {
  local file="$1" name="$2"
  local open="<!-- llm:${name} -->"
  local endmark="<!-- /llm:${name} -->"
  awk -v open="$open" -v endmark="$endmark" '
    function marker_line(s,    t) {
      t = s
      sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t)
      sub(/[[:space:]]+$/, "", t)
      return t
    }
    marker_line($0) == open    { capture=1; next }
    marker_line($0) == endmark { capture=0 }
    capture
  ' "$file"
}

# Replace the body of a `<!-- llm:NAME -->` block in $1 with content read
# from stdin. Markers are preserved. Returns non-zero (file left unchanged) if
# the open OR the close marker is absent.
# Args: file, name.
fm_block_replace() {
  local file="$1" name="$2"
  # Stream stdin to a temp file. Passing multi-line content via `awk -v
  # new_content="$value"` is unsafe — BSD awk (macOS default) rejects real
  # newlines in `-v` assignments with "awk: newline in string", which
  # silently breaks any regen producing >1 row.
  local content_file
  content_file=$(mktemp)
  cat > "$content_file"
  local open="<!-- llm:${name} -->"
  local endmark="<!-- /llm:${name} -->"
  # BOTH markers must exist as their own lines (not just substrings in prose).
  # Fail closed: if the close marker is missing, the rewrite below would set
  # skip=1 at the open marker and never reset it, dropping the entire tail of
  # the file from the open marker to EOF — silent data loss. Refusing leaves
  # the (malformed) file untouched.
  if ! awk -v open="$open" -v endmark="$endmark" '
    { t = $0; sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t); sub(/[[:space:]]+$/, "", t) }
    t == open    { o = 1 }
    t == endmark { c = 1 }
    END { exit !(o && c) }
  ' "$file"; then
    rm -f "$content_file"
    return 1
  fi
  local tmp
  tmp=$(mktemp)
  awk -v open="$open" -v endmark="$endmark" -v content_file="$content_file" '
    function marker_line(s,    t) {
      t = s
      sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", t)
      sub(/[[:space:]]+$/, "", t)
      return t
    }
    marker_line($0) == open {
      print
      while ((getline line < content_file) > 0) print line
      close(content_file)
      skip = 1
      next
    }
    marker_line($0) == endmark {
      skip = 0
      print
      next
    }
    !skip { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
  local rc=$?
  rm -f "$content_file"
  return $rc
}

# Walk all real marker blocks under a tree. Emits:
#   <file>\t<tag>
# with file paths relative to the tree root.
fm_block_walk() {
  local root="${1:-$DOT_LLM_DIR}"
  [[ -d "$root" ]] || return 0

  find "$root" -type f -name '*.md' -print0 | sort -z | while IFS= read -r -d '' file; do
    fm_block_list "$file" | while IFS= read -r tag; do
      [[ -n "$tag" ]] && printf '%s\t%s\n' "${file#"$root"/}" "$tag"
    done
  done
}

# Resolve a tag row link relative to its host file. Emits:
#   <target>\t<status>
# Status values:
#   ok        target exists on disk
#   missing   local target does not exist
#   external  URL/mailto link
#   anchor    in-page anchor
#   template  placeholder/template target
#   empty     no target
fm_tag_resolve_target() {
  local root="$1" host="$2" raw_target="$3"
  local target="${raw_target%%#*}"

  if [[ -z "$raw_target" ]]; then
    printf '\t%s\n' "empty"
    return 0
  fi
  if [[ "$raw_target" == \#* ]]; then
    printf '%s\t%s\n' "$raw_target" "anchor"
    return 0
  fi
  if [[ "$raw_target" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*: ]]; then
    printf '%s\t%s\n' "$raw_target" "external"
    return 0
  fi
  if [[ "$raw_target" == *"<"* || "$raw_target" == *">"* ]]; then
    printf '%s\t%s\n' "$raw_target" "template"
    return 0
  fi

  local candidate
  if [[ "$target" == /* ]]; then
    candidate="$target"
  else
    candidate="$(dirname "$host")/$target"
  fi

  if [[ -d "$candidate" && -f "$candidate/index.md" ]]; then
    candidate="$candidate/index.md"
  fi

  if [[ -e "$candidate" ]]; then
    local abs_root abs_candidate
    abs_root=$(cd "$root" 2>/dev/null && pwd -P) || abs_root=""
    if [[ -d "$candidate" ]]; then
      abs_candidate=$(cd "$candidate" 2>/dev/null && pwd -P) || abs_candidate="$candidate"
    else
      abs_candidate=$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P)/$(basename "$candidate") || abs_candidate="$candidate"
    fi

    if [[ -n "$abs_root" && "$abs_candidate" == "$abs_root/"* ]]; then
      printf '%s\t%s\n' "${abs_candidate#"$abs_root"/}" "ok"
    else
      printf '%s\t%s\n' "$abs_candidate" "ok"
    fi
    return 0
  fi

  printf '%s\t%s\n' "$target" "missing"
}

# Emit every [Link, Description] row in every llm marker block under a tree:
#   <file>\t<tag>\t<link>\t<description>\t<target>\t<status>
# The parser intentionally follows the v4 table shape and keeps validation
# separate: malformed rows are omitted here and surfaced by doctor-specific
# checks.
fm_tag_table_rows() {
  local root="${1:-$DOT_LLM_DIR}"
  [[ -d "$root" ]] || return 0

  find "$root" -type f -name '*.md' -print0 | sort -z | while IFS= read -r -d '' file; do
    awk -v file="$file" -v root="$root" '
      function trim(s) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        return s
      }
      function link_target(cell, raw) {
        raw = cell
        if (match(raw, /\[[^]]+\]\([^)]+\)/)) {
          raw = substr(raw, RSTART, RLENGTH)
          sub(/^.*\]\(/, "", raw)
          sub(/\)$/, "", raw)
        }
        gsub(/`/, "", raw)
        return trim(raw)
      }
      {
        line = $0
        marker = line
        sub(/^[[:space:]]*(#|\/\/)?[[:space:]]*/, "", marker)
        sub(/[[:space:]]+$/, "", marker)
      }
      marker ~ /^<!-- llm:[a-z0-9_:-]+ -->$/ {
        tag = marker
        sub(/^<!-- llm:/, "", tag)
        sub(/ -->$/, "", tag)
        in_block = 1
        next
      }
      marker ~ /^<!-- \/llm:[a-z0-9_:-]+ -->$/ {
        in_block = 0
        next
      }
      in_block && line ~ /^[[:space:]]*\|/ {
        row = line
        if (tolower(row) ~ /^[[:space:]]*\|[[:space:]]*link[[:space:]]*\|[[:space:]]*description[[:space:]]*\|?[[:space:]]*$/) next
        if (row ~ /^[[:space:]]*\|[[:space:]-]+\|[[:space:]-]+\|?[[:space:]]*$/) next

        sub(/^[[:space:]]*\|/, "", row)
        sub(/\|[[:space:]]*$/, "", row)
        n = split(row, cells, /\|/)
        if (n < 2) next

        link = trim(cells[1])
        desc = trim(cells[2])
        for (i = 3; i <= n; i++) desc = desc " | " trim(cells[i])
        target = link_target(link)

        gsub(/\t/, " ", link)
        gsub(/\t/, " ", desc)
        gsub(/\t/, " ", target)
        print file "\t" tag "\t" link "\t" desc "\t" target
      }
    ' "$file" | while IFS=$'\t' read -r host tag link desc target; do
      local resolved status rel_host
      IFS=$'\t' read -r resolved status < <(fm_tag_resolve_target "$root" "$host" "$target")
      rel_host="${host#"$root"/}"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$rel_host" "$tag" "$link" "$desc" "$resolved" "$status"
    done
  done
}
