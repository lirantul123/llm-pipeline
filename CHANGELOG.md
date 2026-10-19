# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-10-19

### Added
- Packaged as a Claude Code plugin with a marketplace in the same repo, so install is `/plugin marketplace add` plus `/plugin install`.
- Builders and the reviewer run as real subagents (`Agent` tool) with a per-stage `model`, so the config table now has an effect.
- Real parallelism: tasks declare `depends_on` and `files`; independent tasks in the same wave are launched together, and tasks that share a file never run at the same time.
- Independent review: a fresh subagent that didn't build the work reads the files, runs the project checks, and cites evidence for every acceptance criterion.
- Acceptance criteria and a verification command for every task.
- Run state saved to `.llm-pipeline/runs/<id>/`, with `/llm-pipeline resume`.
- `go all` to skip checkpoints on small tasks; Stage 0 can skip questions when the task is already clear.
- Safety rules: warns about a dirty git tree before Build; never commits, pushes or runs destructive commands.
- `install.sh` for a manual install, a CI workflow that validates the plugin, an MIT license and manual evals.

### Changed
- Stage prompts are now inlined in `SKILL.md` (Appendix A–D) and actually used. The old `prompts/*.txt` files were never read by the skill. Separate files would also be blocked outside the session's working directory.
- Builders write files to disk instead of pasting code into the chat.

### Removed
- Hard-coded, outdated model IDs.
- The dangling "Notify your team if you have Slack configured" line.

## [0.1.0] — 2026-10-19
- Initial single-file skill.
