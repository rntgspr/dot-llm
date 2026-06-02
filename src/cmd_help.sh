# cmd_help.sh — top-level `llm help` text.

cmd_help() {
  cat <<'EOF'
llm — CLI for the .llm/ framework

Subcommands

  Setup
    install [--framework <name>] [--with <skill>...]  install the framework at .llm/
    uninstall [--yes]                       reverse install: remove .llm/, agent hooks, commands
    doctor [--quiet]                        run health checks on the .llm/ tree (default subcommand)

  Ticket lifecycle
    intake <KEY> [--tracker <name>]         fetch a tracker issue, mirror under .llm/intake/<KEY>/ (jira | linear | clickup)
                                            (archiving a plan: use `llm flow` per the llm-cli skill recipe)

  Marker blocks
    tag                                      list the tags declared in schema.yaml
    tag all [--body|--rows]                  list every tag block in every .llm/*.md
    tag <file>                               audit a file's blocks against the schema
    tag get <file> <tag>                     print the <!-- llm:NAME --> block body
    tag set <file> <tag>                     replace the block body (stdin)

  State maintenance
    update [<path>] [--from <src>] [--keep-prose] [--apply]  update .llm/ files, skills, and slash commands from source
                                            (<path> = a dir or single file under .llm/; version mismatch is a migration review)
    upgrade                                 update the llm tool itself (re-runs the install script; replaces ~/.dot-llm)
    flow <src> <verb> [<dst>]               safe file ops inside .llm/ (verbs: move | copy | create | remove)
                                            (the LLM composes workflows from these via the llm-cli skill)

  help                                      this message

Working on `specs/` (bootstrap, deepen, consolidate) is LLM-driven in v3 — no
subcommand; use the `llm-specs` skill.

Examples
  llm                                  doctor ./.llm (default)
  llm install                          install the starter to ./.llm
  llm install --with git               install + unlock mutating git commands
  llm intake JET-1234                  pull a tracker issue into intake
  llm doctor                           includes the orphan check (tables vs disk)
  llm flow plans/JET-1234/delta-draft.md move archive/JET-1234/delta.md
                                       (file op used by archive recipe in the llm-cli skill)
EOF
}
