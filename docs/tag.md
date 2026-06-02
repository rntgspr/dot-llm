# `llm tag`

Read, write, and audit `<!-- llm:NAME --> ... <!-- /llm:NAME -->` marker blocks. **Schema-validated**: `get` and `set` refuse if `<tag>` is not declared for the target file. The mechanical primitive composed by recipe skills (`llm-archive`, `llm-explore`, `llm-plan`, `llm-specs`, `llm-intake`) — no skill of its own; semantics fit in this doc plus `llm tag --help`.

## Usage

```
llm tag                                  list tags declared for the root index.md
llm tag all [--body|--rows]              list every tag in every .llm/*.md
llm tag <file>                           list the file's actual tags + schema's expected; flag diffs
llm tag [<file>] get <tag>               print the body of <tag>
llm tag [<file>] set <tag> [<content>]   replace the body; content positional or stdin
llm tag get [<file>] <tag>               equivalent verb-first form
llm tag set [<file>] <tag> [<content>]   equivalent verb-first form
```

`<file>` must end in `.md` and is relative to `.llm/` unless absolute. When omitted, it defaults to the root `index.md` (`.llm/index.md`).

Tag name format: `[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*` — colon segments repeat, so deep node-tree names like `plans:plan:handoff:files` are valid. The `llm:` prefix in the file is implicit — pass `specs` or `llm:specs`, both resolve to the same.

## Schema validation

Every `get` / `set` is validated against the schema:
- The tag must be **declared** for the file (root tags, pillar tags, or `meta.tags` with matching `host_file`).
- The set of declared tags comes from the schema walk (`root.tags`, `root.entities.<pillar>.tags`, `meta.tags`).

## Body shape — universal (v4)

Every `<!-- llm:* -->` block has the **same shape**: a markdown table with two columns — `Link` and `Description`. The shape is hardcoded in the parser, doctor, update, and this CLI; schemas don't declare per-tag columns. Add rows, never columns.

```markdown
| Link                          | Description                          |
|-------------------------------|--------------------------------------|
| [name](path/to/index.md)      | one-line prose about the linked file |
```

`list` views show every tag the schema declares alongside what's actually in the file.

## Tree-wide listing

`llm tag all` is the canonical tree-wide walker for marker blocks.

```bash
# Group every tag by host file.
llm tag all

# Dump every marker body.
llm tag all --body

# Machine-readable rows for hooks and doctor:
# file<TAB>tag<TAB>link<TAB>description<TAB>target<TAB>status
llm tag all --rows
```

`--rows` parses only v4 `[Link, Description]` rows and resolves links relative to the file that hosts the tag. Status values are `ok`, `missing`, `external`, `anchor`, `template`, and `empty`.

## Examples

```bash
# List declared tags for the project's root index.md.
llm tag

# Audit a specific file's tags against the schema.
llm tag specs/index.md

# List every tag under .llm/.
llm tag all

# Get the components table body (hosted on domain.md).
llm tag get domain.md components

# Get a pillar index's table.
llm tag get plans/index.md plans
llm tag plans/index.md get plans

# Set a body via positional arg (multi-line works with $'...').
llm tag set intake/index.md intake "$body"
llm tag intake/index.md set intake "$body"

# Set a body via stdin (preferred for long content).
cat <<'EOF' | llm tag specs/index.md set specs
| Link                          | Description                                                                |
|-------------------------------|----------------------------------------------------------------------------|
| [auth](auth/index.md)         | OIDC + session refresh — [api, webapp]; depends on `crypto`; relates `users` |
| [payments](payments/index.md) | Stripe checkout — [api]; depends on `auth`                                  |
EOF
```

## Exit codes

- `0` — success.
- `1` — file/tag absent, validation failure, or write failure.
- `2` — usage error or invalid tag name.

## Why a primitive (no skill)

Skills exist when there's multi-step orchestration that doesn't fit in `--help`. Tag operations are atomic: read a body, write a body, audit a file. The recipe skills (`llm-archive`, `llm-specs`, `llm-plan`, `llm-explore`, `llm-intake`) compose `llm tag set <pillar>/index.md <pillar> <new body>` calls in their bodies to re-emit pillar index rows after structural changes.

## Related

- [`llm flow`](flow.md) — the other CLI primitive (file ops). Recipe skills compose both.
- [`llm doctor`](doctor.md) — orphan check surfaces row drift that `llm tag set` fixes.
- [`llm update`](update.md) — uses `llm tag` internally for marker-preserving merges.
