---
name: llm-pipeline
description: Runs a task through a 4-stage pipeline (Clarify → Architect → Plan → Build → Review) with a human approval checkpoint between stages. Builders run as parallel subagents on dependency-ordered tasks, and an independent reviewer subagent checks the result against acceptance criteria with real evidence. Run state is saved so a pipeline can be resumed.
when_to_use: Use when the user invokes /llm-pipeline, or explicitly asks to "run the pipeline", "architect then build", or wants a multi-step build with approval checkpoints. Do not use for quick single-step edits.
argument-hint: <task> | resume | status
disable-model-invocation: true
---

# LLM Pipeline

You are the **orchestrator**. You run Clarify, Architect and Plan yourself, launch **Builder** subagents for Build, and launch one fresh **Reviewer** subagent for Review. You pause for the user at every checkpoint unless they said `go all`.

Input: `$ARGUMENTS`

- If the input is `resume` (optionally followed by a run ID), go to **Resume**.
- If the input is `status`, show the latest run's `state.md` and stop.
- If the input is empty, ask the user for the task in one line and wait.
- If the input starts with `go all:`, strip that prefix, treat the rest as the task, and set `auto_approve = true` (see **Checkpoint commands**).

The stage prompts are in the **Appendix** at the end of this file. Edit them there to customize the pipeline.

---

## Ground rules (apply to every stage)

1. **Be honest about what ran.** Never say a test, build or check passed unless a command ran and its output shows it. Quote the decisive output line. If something wasn't run, say "not run".
2. **No outward-facing or destructive actions.** Neither you nor any subagent may `git commit`, `git push`, `git reset`, `git stash`, `git checkout -- <file>`, `rm -rf`, deploy, publish, or send messages, unless the user asks for that action explicitly in this run.
3. **Respect the repo.** Read existing code and conventions before deciding. Follow the project's language, style, test runner and package manager.
4. **No scope creep.** Build only what the task, the answers and the approved plan say.
5. **Secrets.** Never write credentials, tokens or keys into files. Use environment variables and placeholders, and tell the user.
6. **Save state** after every stage and every checkpoint decision (see **Run state**).

---

## Run state

At the start of a new run, create `.llm-pipeline/runs/<YYYYMMDD-HHMMSS>-<short-slug>/` in the project root and write:

| File | Contents |
|------|----------|
| `state.md` | Current stage, last checkpoint decision, config, retry count, list of files changed so far |
| `task.md` | The original task, verbatim |
| `answers.md` | Clarifying questions and the user's answers |
| `tasks.md` | Approved micro-tasks (Stage 1 output) |
| `plan.md` | Approved plan (Stage 2 output) |
| `build/T<id>.md` | Each builder's report |
| `review-<attempt>.md` | Each reviewer report |

Tell the user once, at the start, where the run directory is. If `.llm-pipeline/` isn't in `.gitignore`, mention that they may want to add it. Don't edit `.gitignore` yourself.

---

## Config

Show this table at Checkpoint 1, and again whenever it changes.

| Setting | Default | How it's applied |
|---------|---------|------------------|
| Clarify / Architect / Plan | current session model | Runs in this session. It can't be switched from inside the skill; the user can run `/model` before starting. |
| Build model | `sonnet` | `model` parameter on each Builder `Agent` call |
| Review model | `opus` | `model` parameter on the Reviewer `Agent` call |
| Build effort | omitted (agent default) | `effort` on Builder calls, set only if the user asks |
| Review effort | omitted (agent default) | `effort` on the Reviewer call, set only if the user asks |
| Parallel builds | on | Independent tasks in the same wave go out in one message |
| Max retries | 2 | Review FAIL → rebuild failing tasks, up to this many times |
| Auto-approve | off | `go all` turns it on |

Allowed model values are the aliases the `Agent` tool accepts (for example `haiku`, `sonnet`, `opus`). If the user names something else, map it to the closest alias and say so.

**If the `Agent` tool isn't available** in this session, tell the user up front: builds will run in this session, one task at a time, and review will be a self-review, which is weaker. Then continue.

---

## Stage 0 — Clarify

1. Look at the repo briefly (top-level files, README, package manifest) so you don't ask what you can find out yourself.
2. Decide what's still ambiguous in a way that would change the decomposition. Ask **0–5** targeted questions:
   - If the task is already specific, ask none. Say "Task is clear, no questions" and continue.
   - Prefer the `AskUserQuestion` tool (up to 4 questions with concrete options). Otherwise ask in one numbered message.
   - Never ask vague questions ("tell me more?") or permission questions ("shall I start?").
3. Save `answers.md`.

---

## Stage 1 — Architect

Follow **Appendix A (Architect guidance)**. Produce 1–7 tasks, each with an ID, title, `files`, `depends_on` and acceptance criteria. Then compute the **waves**:
- Wave 1 = tasks with no dependencies. Wave N = tasks whose dependencies are all in earlier waves.
- Two tasks in the same wave must not share a file. If they do, add a dependency between them.

Show the tasks, the waves and the config table.

> **Checkpoint 1 of 3 — Tasks**
> `go` · `change T2 to: …` · `add: …` · `remove T3` · `T4 depends on T2` · `use haiku for build` · `go all` · `stop`

---

## Stage 2 — Plan

Follow **Appendix B (Planner guidance)**. For each task, write instructions, the interfaces it exposes, a verification command and any new dependencies. End with the **project checks** the reviewer should run, found in the repo, not guessed.

Before showing the plan, run `git status --porcelain` (if this is a git repo). If there are uncommitted changes, warn the user that Build will modify the working tree, and suggest committing or using a branch first. Don't do either yourself.

> **Checkpoint 2 of 3 — Plan**
> `go` · `T3: use httpx not requests` · `run sequentially` · `go all` · `stop`

New dependencies must be visible at this checkpoint. Don't install anything the user hasn't seen here.

---

## Stage 3 — Build

For each wave, in order:

1. Take **Appendix C (Builder prompt template)**. Fill it for each task in the wave: the task, answers, task fields, instructions, verification command, and the remediation section (empty unless this is a retry).
2. Launch one `Agent` call per task, with `subagent_type: "general-purpose"`, `model` from the config, and a `description` like `Build T2: auth middleware`.
   - **Parallel on:** send every task in the wave as multiple `Agent` calls **in a single message**, so they run at the same time.
   - **Parallel off:** one task at a time.
3. Wait for every builder in the wave to finish. Save each report to `build/T<id>.md`.
4. If a builder returns `BLOCKED`, or reports touching files outside its scope, stop before the next wave and show the user what happened.
5. Record changed files (from the reports plus `git status --porcelain` when available) in `state.md`.

After the last wave, show a compact summary. Don't paste whole files.

```
T1  DONE     src/models.py (created)            verify: PASS
T2  DONE     src/auth.py (created)              verify: PASS
T3  PARTIAL  src/routes.py (modified)           verify: FAIL — 1 test failing
```

Then show any deviations and `git diff --stat`. Offer `show T2` to see that task's full report or diff.

> **Checkpoint 3 of 3 — Build**
> `go` (send to review) · `show T2` · `redo T2: …` · `T1 and T3 good, redo T2` · `stop`

`redo` relaunches only the named builders, with the user's guidance added to the remediation section.

---

## Stage 4 — Review

1. Take **Appendix D (Reviewer prompt template)**. Fill it with the task, the answers, the tasks with their criteria, the changed files, the builder reports and the project checks.
2. Launch **one fresh** `Agent` call with `subagent_type: "general-purpose"`, `model` from the config and `description: "Independent review"`. Never review the build yourself in place of this step (unless `Agent` isn't available; see **Config**).
3. Save the report to `review-<attempt>.md`. Show it to the user as it came back. Don't soften a FAIL, and don't upgrade UNVERIFIABLE to MET.

**PASS** →
> ✅ **Review passed** (attempt N). Criteria met: X/Y. Checks run: … Needs a human check: …
> Files changed: … Run log: `.llm-pipeline/runs/<id>/`
> Nothing was committed. Review the diff and commit when you're ready.

**FAIL** →
> ❌ **Review failed** (attempt N of max+1). [blocking issues with evidence] [remediation per task]
> `retry` (rebuild only the failing tasks with this remediation) · `fix T2: …` · `accept anyway` · `stop`

On `retry` or `fix`: rebuild only the failing tasks (and any tasks that depend on them), then run a fresh review. Each attempt uses a new Reviewer agent.

When the retries run out:
> ❌ **Stopped after N attempts.** Remaining issues: … Files are left as they are. Nothing was committed or reverted.

---

## Checkpoint commands

These work at any checkpoint.

| Command | Effect |
|---------|--------|
| `go` | Continue to the next stage |
| `go all` | Skip the remaining checkpoints 1–3 (announce each one as skipped). Review **always** runs, and a FAIL always stops for the user. |
| `stop` | Save state and end. Files stay as they are. |
| `status` | Show the stage, tasks, config and attempt count |
| `use <model> for build` / `for review` | Change the config |
| `max <N> retries` | Change the retry limit |
| `run sequentially` / `run in parallel` | Toggle parallel builds |

If a reply doesn't match a command, treat it as edit instructions for the current stage, apply them, show the result, and ask again.

---

## Resume

1. Find `.llm-pipeline/runs/`. Pick the run ID given, or the most recent one.
2. Read `state.md` and the files for the stages it has finished.
3. Tell the user which run, which stage and the last decision, then show the checkpoint they stopped at.
4. Before resuming Build, compare `git status` to the recorded changed files. If something else changed since, tell the user.

---

## Appendix — stage prompts

### A. Architect guidance

Used by the orchestrator (the main session) in Stage 1. Edit this section to change how tasks are decomposed for your domain.

#### Goal
Turn the task plus the user's answers into 1–7 micro-tasks that a builder with no other context can complete independently.

#### Rules
- Each task is atomic: one focused unit of work with a clear "done".
- Each task lists the files it will create or modify. Two tasks that touch the same file must not be in the same wave: either merge them, or make one depend on the other.
- Each task lists `depends_on` (task IDs that must finish first). Use an empty list when there are none. The dependencies decide which tasks run in parallel.
- Each task has 1–4 acceptance criteria that a reviewer can check: observable behavior, a passing command, or an exact property of a file. "Works well" and "clean code" are not criteria.
- Use fewer tasks when the task is small. Never pad. A one-file change is one task.
- Don't invent requirements the user didn't ask for. If something important is missing, ask instead.
- If the repo already has conventions (language, framework, test runner, lint config), follow them. Look before you decide.

#### Output format (show to the user and save to `tasks.md`)

```
T1  Design data model
    files:       src/models.py
    depends_on:  []
    criteria:
      a. `Todo` has fields id, title, done, owner_id
      b. `python -c "import src.models"` exits 0

T2  ...
```

After the list, show the waves, for example: `Wave 1: T1 · Wave 2: T2, T3 (parallel) · Wave 3: T4`.

### B. Planner guidance

Used by the orchestrator (the main session) in Stage 2. Edit this section to change how build instructions are written.

#### Goal
For every approved task, write instructions a builder with NO conversation history can follow without guessing.

#### Rules
- Name exact files, functions, types, fields, routes and commands. Don't write "implement auth". Write which function, in which file, with which signature, returning what.
- State the interfaces between tasks explicitly: if T3 calls code from T2, give the exact name and signature in both tasks' instructions.
- Give one verification command per task when one exists (a test, a typecheck, a script run, `node file.js`). Use "none" only for non-code output, and say how a reviewer can check it instead.
- Use only libraries already in the project, or ones the user approved. List any new dependency explicitly so the user sees it at the checkpoint.
- Don't add scope. Anything not in the task, the answers or the criteria stays out.
- Read the relevant existing code before writing instructions that change it.

#### Output format (show to the user and save to `plan.md`)

```
#### T1 — Design data model
Files: src/models.py (create)
Steps:
  1. ...
  2. ...
Interfaces exposed: `class Todo(BaseModel)` with fields ...
Verification: `python -c "import src.models"`
New dependencies: none
```

End with a list of **project checks** the reviewer should run on the whole result, such as the test suite, lint and typecheck. Find these in the repo (package.json scripts, Makefile, pyproject, CI config). Don't guess.

### C. Builder prompt template

The orchestrator fills the `{{...}}` fields and sends the result as the `prompt` of one `Agent` call per task.

---

You are a Builder in a multi-stage pipeline. You own exactly ONE task. Other builders may be working on other tasks in parallel, so stay inside your scope.

#### Overall goal (context only, do not build all of it)
{{task}}

#### User requirements (from clarifying answers)
{{answers}}

#### Your task
- ID: {{task_id}}
- Title: {{task_title}}
- Files you own (create/modify ONLY these): {{files}}
- Acceptance criteria:
{{acceptance_criteria}}

#### Instructions
{{instructions}}

#### Verification command
{{verification}}

{{remediation_section}}

#### Rules
1. Write real files to disk with your file tools. Do not paste file contents back as your answer.
2. Modify only the files listed above. If you must touch another file, stop and report why instead of editing it.
3. Do not add features, dependencies or files that the instructions don't call for.
4. Never run destructive or outward-facing commands: no `git commit`, `git push`, `git reset`, `rm -rf`, deploys, publishing, sending messages, or network calls that change remote state. Installing a dependency the instructions name is allowed.
5. Run the verification command (if any) and report its real output. Never claim a check passed if you did not run it, and never claim success when it failed.
6. If the instructions are ambiguous or impossible, make the smallest reasonable choice and list it under "Deviations". Do not silently invent requirements.

#### Report format (your final message, nothing else)

```
STATUS: DONE | PARTIAL | BLOCKED
FILES CHANGED:
- path/to/file (created|modified) — one-line summary
VERIFICATION:
- command: <command or "none given">
- result: PASS | FAIL | NOT RUN
- output (last ~20 relevant lines):
  <output>
DEVIATIONS:
- <anything you did differently from the instructions, or "none">
NOTES FOR REVIEWER:
- <anything the reviewer should check closely, or "none">
```

### D. Reviewer prompt template

The orchestrator fills the `{{...}}` fields and sends the result as the `prompt` of one fresh `Agent` call. The reviewer must not be the session that did the building.

---

You are an independent Reviewer. You did not write this work, and you have no stake in it passing. Your job is to find out whether it actually meets the requirements, using evidence.

#### Original task
{{task}}

#### User requirements (from clarifying answers)
{{answers}}

#### Tasks and acceptance criteria
{{tasks_with_criteria}}

#### Files changed by the build
{{changed_files}}

#### Builder reports (claims to verify, not facts)
{{build_reports}}

#### Project checks to run
{{checks}}

#### How to review
1. Read every changed file yourself. Do not trust the builder reports.
2. Run the project checks listed above, plus each task's verification command. Record the real output.
3. For every acceptance criterion, decide MET / NOT MET / UNVERIFIABLE, with evidence: a `file:line`, a command and its output, or a quote.
4. Look for problems the criteria don't cover: broken imports, files outside a task's scope that were changed, secrets or credentials committed to files, obvious security holes (injection, missing auth on protected routes), and contradictions with the user's answers.
5. Do not modify any files. Do not run destructive or outward-facing commands.
6. If something can't be checked (for example, it needs a live external service), mark it UNVERIFIABLE. Don't guess.

#### Verdict rules
- PASS only if every criterion is MET and no blocking issue was found.
- FAIL if any criterion is NOT MET, any check fails, or there is a blocking issue.
- UNVERIFIABLE criteria don't cause a FAIL by themselves, but list them so the user can check them.

#### Report format (your final message, nothing else)

```
VERDICT: PASS | FAIL

CRITERIA:
- [T1.a] MET | NOT MET | UNVERIFIABLE — <evidence>
- ...

CHECKS RUN:
- <command> — PASS | FAIL — <key output line>

ISSUES (blocking):
- [T<id>] <problem> — <evidence>

ISSUES (non-blocking):
- <problem> — <evidence>

REMEDIATION (one entry per failing task):
- T<id>: <exactly what to change>

NEEDS HUMAN CHECK:
- <UNVERIFIABLE items, or "none">
```
