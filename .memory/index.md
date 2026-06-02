# Load all markdowns below:

- [dot-llm framework](dot-llm.md) — what the repo is, layout, v4 CLI surface
- [v4 model and universal tag shape](v4_model.md) — recursive node tree, tracker-agnostic intake, `[Link, Description]` hardcoded for every tag block
- [frameworks layout](frameworks_layout.md) — multi-flavor (frameworks/__base + frameworks/<name>/); universal vs flavor-specific skills; install order with skip-if-exists
- [universal index + loading rule](universal_index.md) — index.md byte-identical across all flavors from __base; loading rule is the kernel; flavor-specifics → domain.md as a depends-on
- [iac-basic flavor](iac_flavor.md) — tool-agnostic IaC flavor; topology/ + runbooks/ durable, apps=environments, no ghost role; shipped, folded into main, PR #11 auto-closed
- [install command state](install_state.md) — current state of `llm install`; `llm upgrade` (re-runs install script) + kernel drift check in install.sh (2026-06-09)
- [test bench](test_bench.md) — `bulbasaur/ext-api-cad` is the real test project for dogfooding the `llm` CLI
- [test process](test_process.md) — repeatable test cycle: uninstall-first → verify clean → install → test → report
- [superpowers → disciplines](superpowers_absorption.md) — don't enable the plugin; absorb select execution skills via the "discipline" artifact (loading-rule-loaded, domain-attached); skill-to-discipline tool
- [TODO: implementation gaps review](todo_review_gaps.md) — open items + v4 work stream
- [User: Renato](user_renato.md) — role and context
- [Feedback: git read-only](feedback_git_readonly.md) — git is read-only by default
- [Feedback: install.sh is destructive](feedback_install_sh_destructive.md) — never run install.sh / llm upgrade without explicit ask; it rm -rf ~/.dot-llm and breaks the workspace symlink
- [Feedback: update/reconcile design](feedback_update_design.md) — tag bodies + FM values never auto-overwritten; skills/commands replaced deterministically; v4 collapses kinds into one hardcoded shape
- [Feedback: compact text, reference templates](feedback_compact_text.md) — prefer compactness over duplication
- [Feedback: communication style](feedback_communication.md) — pt-BR chat, English artifacts, terse responses

@./feedback_communication.md
@./feedback_compact_text.md
@./feedback_git_readonly.md
@./feedback_install_sh_destructive.md
@./feedback_update_design.md
@./dot-llm.md
@./frameworks_layout.md
@./iac_flavor.md
@./install_state.md
@./superpowers_absorption.md
@./test_bench.md
@./test_process.md
@./universal_index.md
@./v4_model.md
@./user_renato.md
