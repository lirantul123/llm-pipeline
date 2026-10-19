---
name: llm-pipeline
description: Runs any task through a 4-stage LLM pipeline (Architect → Plan → Build → Review) with human-in-the-loop approval at every stage. Architect asks clarifying questions before decomposing. User can adjust micro-tasks, plan, build outputs, and config at each checkpoint.
---

# LLM Pipeline Skill

When activated, run the task through this pipeline. You ARE the pipeline — no API server needed. Execute each stage inline, pause for user approval between stages, and carry context forward.

---

## Stage 0 — Understand the task

Before doing anything, read the task and ask **3–5 smart clarifying questions** based on what would most change the decomposition. Do NOT ask generic questions. Think: what ambiguity would send this task in completely different directions?

Examples of GOOD questions (pick the ones relevant to THIS task):
- "What language / framework?" (if task is about code)
- "What's the target audience?" (if task is about content)
- "Are there existing systems this must integrate with?"
- "What does success look like — what would make you say this is done?"
- "Any constraints I should know about (performance, security, style)?"
- "Should I prioritize speed of delivery or completeness?"

Examples of BAD questions (never ask these):
- "Can you tell me more?" (too vague)
- "What is the task?" (they already told you)
- "Do you want me to start?" (yes, that's why they activated the skill)

Ask all your questions in ONE message. Number them. Wait for answers before proceeding.

---

## Stage 1 — Architect

Use the task + answers to decompose into **3–7 atomic micro-tasks**.

Show the micro-tasks as a numbered list. Then ask:

> **Checkpoint 1 of 3 — Micro-tasks**
> Review the list above. You can:
> - Type **"go"** to continue
> - Edit any task (say "change 2 to: ...")
> - Add a task (say "add: ...")
> - Remove a task (say "remove 3")
> - Change the model/effort: "use opus max for this stage"

Wait for response. Apply any changes. Then proceed.

---

## Stage 2 — Plan

For each micro-task, write exact step-by-step build instructions. Show the full plan.

> **Checkpoint 2 of 3 — Build Plan**
> Review the instructions for each task above. You can:
> - Type **"go"** to continue
> - Adjust any task's instructions (say "task 2: also include X")
> - Change build config: "run builds sequentially" / "use opus for build"

Wait for response. Apply changes. Then proceed.

---

## Stage 3 — Build

Execute each task's instructions. Run **in parallel by default** (work through all tasks, present all results). If user said sequential, do one at a time.

Show each completed task's output clearly labeled:

```
─── Build [0]: Design data model ──────────────────────────
[output here]
────────────────────────────────────────────────────────────
```

> **Checkpoint 3 of 3 — Build Outputs**
> Review each output above. You can:
> - Type **"go"** to send to review
> - Request a fix: "redo task 2, it's missing error handling"
> - Accept partially: "tasks 1 and 3 are good, redo 2"
> - Provide guidance: "for task 2, use X instead of Y"

Wait for response. Apply any fixes. Then proceed.

---

## Stage 4 — Review

Validate ALL build outputs against the original task and the user's clarifying answers.

If **PASS**:
> ✅ **Review passed** — all outputs satisfy the original requirements.
> [brief summary of what was built]

If **FAIL**:
> ❌ **Review failed** — issues found:
> [list issues clearly]
> 
> Remediation: [specific fixes]
>
> Options:
> - **"retry"** — auto-retry with remediation injected (attempt N/max_retries)
> - **"fix [task]"** — you specify the fix manually
> - **"stop"** — end the run here with current outputs

On auto-retry: inject remediation into Build prompts and re-run. Max 3 retries by default (user can override at any checkpoint).

After 3 failed retries with no user override:
> ❌ **Pipeline exhausted** — 3 retries failed. Final issues:
> [issues list]
> Notify your team if you have Slack configured.

---

## Config defaults (user can override at any checkpoint)

| Setting | Default | Override phrase |
|---------|---------|-----------------|
| Build parallelism | parallel | "run sequentially" |
| Architect model | claude-opus-4-8, effort xhigh | "use [model] for architect" |
| Plan model | claude-opus-4-8, effort high | "use [model] for plan" |
| Build model | claude-sonnet-4-6, effort medium | "use [model] for build" |
| Review model | claude-sonnet-4-6, effort low | "use [model] for review" |
| Max retries | 3 | "max [N] retries" |

---

## How to activate

In any Claude Code session (from inside the `llm-pipeline` repo or with this skill installed):

```
/llm-pipeline Build a REST API for a todo list with JWT auth
```

Or just activate the skill and paste your task when prompted.
