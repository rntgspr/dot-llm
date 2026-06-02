# Architecture — the kernel, the universal index, and flavors

## The loading rule is the kernel

The whole framework revolves around one rule: **load only what is declared, by a guided traversal of the node tree.** At each step the *structure* proposes candidates (the entries a node lists as children + the nodes in its `depends-on`/`relates`) and the *LLM* prunes them by relevance to the task subject and the context accumulated so far; the traversal recurses into surviving indexes and terminates at a leaf (a file with no `depends-on` and no child index).

This is **deterministic in structure** (what each node declares, and where a branch ends, is fixed) and **judgment-driven in selection** (which candidates are relevant is the LLM's call). Tooling can *expand* a node — list its declared candidates, their subjects, and whether each is an index or a leaf — but the pruning and the recursion stay with the LLM.

## Universal artifacts are identical across every flavor

Three artifact sets are **byte-identical** in `__base` and in every flavor:

1. **`index.md`** — the framework kernel: node model, loading rule, conduct, language. Carries no domain content.
2. **`skills/llm-doctor/`, `skills/llm-install/`, `skills/llm-update/`** — universal multi-step orchestration; same SKILL.md across all flavors.
3. **`commands/llm/doctor.md`, `commands/llm/update.md`, `commands/llm/resolve.md`** — pure mechanics, no flavor-specific recipe content.

All three are authored once in `frameworks/__base/` and propagated verbatim into every `frameworks/<flavor>/`. Flavor-specific content (its pillars, roles, additional skills, additional slash commands) lives only in the flavor.

- The kernel `index.md` carries a blockquote header at the top stating that the file is framework-owned and must not be edited. The whole file (loading rule, conduct, language, etc.) is plain prose — outside any `<!-- llm:NAME -->` tag — so `llm update` carries it from source. Adopter-owned blocks (`components`, `root`) live in `domain.md`, where the tag-body preservation rule protects them.
- A drift-check enforces that every flavor's universal artifacts match `__base`'s. It runs in the **install script** (`llm upgrade` re-runs it): a snapshot where any flavor diverges is refused. It is deliberately NOT a `llm doctor` check — doctor audits the **adopter's** tree, which never contains `__base` to compare against. See "Reuse" below.

## Flavor-specifics live in `domain.md`

Everything domain-specific — the pillars, the roles, the entry-point refinement, the domain context — lives in **`domain.md`**, declared as a `depends-on` of the root `index.md`. This dogfoods the loading rule: loading `index.md` surfaces `domain.md` as a candidate and pulls it in. Every flavor (including `__base`) ships this file so the dependency never dangles.

## Why prose, not tags — and why not symlinks

- **Tags won't work:** tag bodies are adopter data, never overwritten on `llm update`. The shared kernel must propagate framework → adopter, so it is prose, not a tag.
- **Symlinks won't work:** fragile on Windows (admin/Developer-Mode, `git core.symlinks`, editor breakage), and the adopter never receives `__base` (install copies only the chosen flavor), so a link would dangle.

## Reuse mechanism

Propagation is a **verbatim copy** of every file under `__base/{index.md, skills/, commands/}` into each flavor, plus a **deterministic drift-check** (`cmp` per file in the install script) that aborts the install when any flavor's universal artifact diverges from `__base`. The maintainer edits `__base`, re-copies into the flavors, and the check guards against shipping a drifted snapshot. (A build-time include was considered and set aside as more machinery for a marginal gain.)
