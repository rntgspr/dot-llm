#!/usr/bin/env bash
set -euo pipefail

REPO="git@github.com:rntgspr/dot-llm.git"
DEST="$HOME/.dot-llm"
BIN="$HOME/.local/bin"

echo "Installing dot-llm to $DEST..."

# $DEST is treated as a plain framework snapshot, not a working tree the
# user maintains. Every run replaces it wholesale: wipe, fresh shallow
# clone, strip .git/ so re-runs cannot diverge or be blocked by a dirty
# index. This is the upgrade path — no prompt before overwrite by design.
rm -rf "$DEST"
git clone --depth=1 "$REPO" "$DEST"
rm -rf "$DEST/.git"

# Kernel integrity check: index.md, every skill under skills/, and every
# command under commands/llm/ are authored once in frameworks/__base and
# propagated verbatim into every flavor. A snapshot where any flavor's
# copy of a universal artifact diverges from __base's is a broken
# distribution — refuse it.
BASE_DIR="$DEST/frameworks/__base"

# 1) index.md — single file at the flavor root.
for flavor_index in "$DEST"/frameworks/*/index.md; do
  [[ "$flavor_index" == "$BASE_DIR/index.md" ]] && continue
  if ! cmp -s "$BASE_DIR/index.md" "$flavor_index"; then
    echo "✗ kernel drift: $flavor_index differs from frameworks/__base/index.md" >&2
    echo "  The snapshot is inconsistent — report this upstream. Aborting." >&2
    exit 1
  fi
done

# 2) Universal skills + commands — every file under __base/skills/ and
# __base/commands/ must exist byte-identical in each flavor.
while IFS= read -r src; do
  rel="${src#"$BASE_DIR"/}"
  for flavor_dir in "$DEST"/frameworks/*/; do
    flavor_dir="${flavor_dir%/}"
    [[ "$flavor_dir" == "$BASE_DIR" ]] && continue
    dest="$flavor_dir/$rel"
    if [[ ! -f "$dest" ]]; then
      echo "✗ kernel drift: $dest missing (must mirror frameworks/__base/$rel verbatim)" >&2
      exit 1
    fi
    if ! cmp -s "$src" "$dest"; then
      echo "✗ kernel drift: $dest differs from frameworks/__base/$rel" >&2
      exit 1
    fi
  done
done < <(find "$BASE_DIR"/skills "$BASE_DIR"/commands -type f 2>/dev/null)

mkdir -p "$BIN"
ln -sf "$DEST/llm" "$BIN/llm"

echo "Done. Make sure $BIN is on your PATH."
echo "  llm help"
