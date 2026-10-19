# llm-pipeline

[![validate](https://github.com/lirantul123/llm-pipeline/actions/workflows/validate.yml/badge.svg)](https://github.com/lirantul123/llm-pipeline/actions/workflows/validate.yml)
![version](https://img.shields.io/badge/version-1.0.0-blue)
![license](https://img.shields.io/badge/license-MIT-green)

A Claude Code skill that runs a task through **Clarify → Architect → Plan → Build → Review**, and stops for your approval between stages.

- **You stay in control.** There are three checkpoints where you can edit tasks, change the plan or redo a build.
- **Real parallel builds.** Each task runs in its own subagent. Tasks that don't depend on each other run at the same time, and tasks that touch the same file never do.
- **Independent review.** A fresh reviewer subagent, which didn't write the code, reads the files, runs your project's checks, and cites evidence for every acceptance criterion.
- **Resumable.** Every run is saved to `.llm-pipeline/runs/<id>/`. Continue later with `/llm-pipeline resume`.
- **Safe by default.** It never commits, pushes, resets or deploys. It warns you before building on a dirty working tree.

No server and no API key. It runs inside Claude Code.

---

## Requirements

- [Claude Code](https://code.claude.com). The one-line plugin install needs **v2.1.275 or later** (`claude --version`). The manual install works on older versions.
- Builds and review run as subagents through the `Agent` tool. If your setup doesn't have it, the skill tells you and falls back to running everything in one session (no parallelism, and only a self-review).

---

## Install

### Option 1: Plugin (recommended)

In Claude Code:

```
/plugin install llm-pipeline --marketplace lirantul123/llm-pipeline
```

On older versions, use the two-step form:

```
/plugin marketplace add lirantul123/llm-pipeline
/plugin install llm-pipeline@llm-pipeline
```

Plugin skills are namespaced, so you invoke it as **`/llm-pipeline:llm-pipeline`**. To update later, run `/plugin marketplace update llm-pipeline`.

### Option 2: Manual install (gives you `/llm-pipeline`)

```bash
git clone https://github.com/lirantul123/llm-pipeline.git
cd llm-pipeline
./install.sh            # copy into ~/.claude/skills/llm-pipeline/
./install.sh --link     # or: symlink, so a `git pull` updates it
./install.sh --project  # or: install into ./.claude/skills/ of the current repo only
```

Without the script:

```bash
mkdir -p ~/.claude/skills
cp -R skills/llm-pipeline ~/.claude/skills/llm-pipeline
```

> Claude Code only finds a skill at `~/.claude/skills/<name>/SKILL.md`: a folder holding a file named exactly `SKILL.md`. A loose `~/.claude/skills/llm-pipeline.md` is ignored.

### Then restart Claude Code

Skills load when a session starts. Exit and run `claude` again, then type `/` and check that `llm-pipeline` is listed.

---

## Usage

```
/llm-pipeline Build a REST API for a todo list with JWT auth, using the existing Express app
/llm-pipeline go all: add a --version flag to cli.py     # skip checkpoints; review still runs
/llm-pipeline resume                                     # continue the most recent run
/llm-pipeline status                                     # show where the latest run is
```

(Use `/llm-pipeline:llm-pipeline` in place of `/llm-pipeline` if you installed the plugin.)

**Tip:** commit or branch before you start. The pipeline writes to your working tree and leaves committing to you.

---

## What happens

```
Your task
   │
   ▼
Stage 0  Clarify     Reads the repo, then asks 0–5 questions (none if the task is already clear)
   │
   ▼
Stage 1  Architect   1–7 tasks, each with files, depends_on and acceptance criteria
   │                 → grouped into waves of independent tasks
   ├── Checkpoint 1: edit, add or remove tasks, change models
   ▼
Stage 2  Plan        Exact steps, interfaces, a verification command per task,
   │                 new dependencies, and the project checks for review
   ├── Checkpoint 2: adjust instructions (warns here if git tree is dirty)
   ▼
Stage 3  Build       One builder subagent per task. Each wave's tasks run in parallel.
   │                 Builders write files, run their verification and report honestly.
   ├── Checkpoint 3: see the summary and diffstat, `show T2`, `redo T2: …`
   ▼
Stage 4  Review      A fresh reviewer subagent reads the files, runs the checks,
                     and marks each criterion MET / NOT MET / UNVERIFIABLE with evidence.
                     PASS → done.  FAIL → `retry` rebuilds only the failing tasks (max 2 by default)
```

### Example build summary (Checkpoint 3)

```
T1  DONE     src/models.py (created)            verify: PASS
T2  DONE     src/auth.py (created)              verify: PASS
T3  PARTIAL  src/routes.py (modified)           verify: FAIL — 1 test failing
```

---

## Commands at a checkpoint

| You say | Effect |
|---------|--------|
| `go` | Continue |
| `go all` | Skip the remaining checkpoints. Review still runs, and a FAIL still stops. |
| `change T2 to: …` · `add: …` · `remove T3` | Edit tasks (Checkpoint 1) |
| `T4 depends on T2` | Add a dependency |
| `T3: use httpx not requests` | Adjust the plan (Checkpoint 2) |
| `show T2` · `redo T2: add error handling` | Inspect or rebuild one task (Checkpoint 3) |
| `retry` · `fix T2: …` · `accept anyway` | After a review FAIL |
| `use haiku for build` · `use opus for review` | Change a subagent's model |
| `run sequentially` · `max 3 retries` | Change the config |
| `status` · `stop` | Show progress, or save and end |

Anything else you type is treated as edit instructions for the current stage.

---

## Config defaults

| Setting | Default | Notes |
|---------|---------|-------|
| Clarify / Architect / Plan | your current session model | These stages run in your session. Use `/model` before starting to change it. |
| Build model | `sonnet` | Sent as `model` on each builder subagent |
| Review model | `opus` | Sent as `model` on the reviewer subagent |
| Parallel builds | on | Per wave, never for tasks that share files |
| Max retries | 2 | |

---

## Run files

Each run writes to `.llm-pipeline/runs/<timestamp>-<slug>/`:

```
state.md        current stage, config, retry count, changed files
task.md         your task, verbatim
answers.md      clarifying Q&A
tasks.md        approved tasks and waves
plan.md         approved plan
build/T1.md     each builder's report
review-1.md     each review (one per attempt)
```

These are useful for audits and for `resume`. Add `.llm-pipeline/` to your `.gitignore` if you don't want them committed.

---

## Customize

The stage prompts are in the **Appendix** of [`skills/llm-pipeline/SKILL.md`](skills/llm-pipeline/SKILL.md):

| Section | Controls |
|---------|----------|
| A. Architect guidance | How tasks are split, and what counts as an acceptance criterion |
| B. Planner guidance | How detailed the instructions are, and how project checks are found |
| C. Builder prompt template | The builder subagent's prompt, rules and report format |
| D. Reviewer prompt template | The reviewer subagent's prompt, evidence rules and verdict format |

They're inlined on purpose. Claude Code doesn't let a session read files outside its working directory without asking, so separate prompt files would trigger permission prompts or fail in headless runs. If you installed with `--link`, edit them in your clone. Otherwise, edit the installed copy.

---

## Safety and limits

- **Never automatic:** `git commit`, `push`, `reset`, `stash`, deleting files with `rm -rf`, deploys, publishing, or sending messages. This applies to the orchestrator and every subagent.
- **Secrets:** builders are told never to write credentials into files.
- **Honesty:** "passed" is only claimed with command output to back it up. Anything that can't be checked locally is reported as UNVERIFIABLE, for you to check.
- **Limits:** this is a prompt-driven workflow, not a sandbox. Subagents run with your normal Claude Code permissions, so keep your permission mode to what you'd allow for any session. Review quality depends on your project having runnable checks (tests, lint, typecheck).

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `/llm-pipeline` not in the `/` menu | Check the file is at `~/.claude/skills/llm-pipeline/SKILL.md` (not a flat `.md`), then restart Claude Code |
| Plugin installed, `/llm-pipeline` not found | Plugin skills are namespaced: use `/llm-pipeline:llm-pipeline` |
| `/plugin install … --marketplace` not recognized | Claude Code is older than 2.1.275. Use the two-step install |
| Builds run one at a time | The `Agent` tool isn't available, or the tasks depend on each other (see the waves at Checkpoint 1) |

---

## Development

```bash
claude plugin validate . --strict   # same check CI runs
```

Before a release, run the manual cases in [`evals/README.md`](evals/README.md), bump `version` in `.claude-plugin/plugin.json`, and add a [`CHANGELOG.md`](CHANGELOG.md) entry (CI checks that they match).

```
llm-pipeline/
├── .claude-plugin/
│   ├── plugin.json          plugin manifest
│   └── marketplace.json     lets this repo act as its own marketplace
├── skills/llm-pipeline/
│   └── SKILL.md             orchestrator + stage prompts (Appendix A–D)
├── evals/README.md          manual release checks
├── install.sh               manual installer
├── .github/workflows/       CI: validate plugin, manifests, script
├── CHANGELOG.md
└── LICENSE                  MIT
```

Contributions are welcome. Open an issue describing the change, and include eval results in your PR.

---

<sub>Interactive docs for v0.1 (older design, which may not match this version): [artifact](https://claude.ai/artifact/SxE3UKhSE63vPpRZKx6j7r?sk=Bxsn-kjGipAK_4GFFe_VRg)</sub>
