# llm-pipeline

A Claude Code skill that runs any task through a 4-stage LLM pipeline with human-in-the-loop control at every step.

**No server. No API. Just activate the skill and go.**

---

## How it works

```
Your task
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 0 — Clarify                                      │
│  Claude asks 3–5 smart questions specific to your task  │
└──────────────────────┬──────────────────────────────────┘
                       │ your answers
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 1 — Architect          [claude-opus-4-8 · xhigh] │
│  Decomposes task into 3–7 atomic micro-tasks            │
│  ► Checkpoint: review & edit the list                   │
└──────────────────────┬──────────────────────────────────┘
                       │ approved micro-tasks
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 2 — Plan               [claude-opus-4-8 · high]  │
│  Writes exact step-by-step instructions per micro-task  │
│  ► Checkpoint: review & adjust any instructions         │
└──────────────────────┬──────────────────────────────────┘
                       │ approved plan
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 3 — Build              [claude-sonnet-4-6]       │
│  Executes each task in parallel (configurable)          │
│  ► Checkpoint: review outputs, request fixes            │
└──────────────────────┬──────────────────────────────────┘
                       │ approved outputs
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 4 — Review             [claude-sonnet-4-6]       │
│  Validates all outputs against task + your requirements │
│  PASS → done. FAIL → retry with remediation (max 3×)   │
└─────────────────────────────────────────────────────────┘
```

---

## Install the skill

Copy the skill file to your Claude Code skills directory:

```bash
cp skill/llm-pipeline.md ~/.claude/skills/llm-pipeline.md
```

---

## Usage

Activate the skill in any Claude Code session:

```
/llm-pipeline Build a REST API for a todo list with JWT auth
```

Claude will ask 3–5 clarifying questions tailored to your task. Answer them, then the pipeline runs — pausing at each stage for your review.

---

## Example session

```
You:  /llm-pipeline Build a Slack bot that summarizes daily standup messages

Claude: Before I start, a few questions:
        1. What Slack workspace / channel structure? (single channel or multi?)
        2. What format should the summary be? (bullet points, paragraph, table?)
        3. Should it post automatically on a schedule or on command?
        4. Where does it need to run? (AWS Lambda, a server, local?)
        5. Any existing Slack app or starting from scratch?

You:   1. single #standup channel  2. bullet points, grouped by person
        3. on command: /summarize  4. AWS Lambda  5. scratch

Claude: ✓ Architect complete — here are the micro-tasks:
        1. Set up Slack app manifest and bot token scopes
        2. Implement Lambda handler for /summarize slash command
        3. Fetch and parse last 24h of messages from #standup
        4. Summarize messages grouped by author using Claude API
        5. Post formatted summary back to channel

        Checkpoint 1 of 3 — type "go" to continue, or edit the list.

You:   go

Claude: ✓ Plan complete — [shows detailed instructions for each task]

        Checkpoint 2 of 3 — type "go" or adjust any task's instructions.

You:   task 3: only fetch messages since midnight UTC, not last 24h

Claude: Updated. ✓ Building...

        ─── Build [0]: Slack app manifest ─────────────────────────
        [full output]
        ────────────────────────────────────────────────────────────
        ─── Build [1]: Lambda handler ──────────────────────────────
        [full output]
        ...

        Checkpoint 3 of 3 — type "go" to send to review, or request fixes.

You:   go

Claude: ✅ Review passed — all outputs satisfy requirements.
```

---

## Adjusting each stage

At every checkpoint you can:

| What you want | What to say |
|---------------|-------------|
| Continue | `go` |
| Edit a micro-task | `change 2 to: implement X using Y` |
| Add a micro-task | `add: also write integration tests` |
| Remove a micro-task | `remove 4` |
| Adjust a plan instruction | `task 3: use httpx not requests` |
| Redo a build output | `redo task 2, add error handling` |
| Change model for a stage | `use opus max for build` |
| Run builds sequentially | `run sequentially` |
| Limit retries | `max 1 retry` |
| Stop early | `stop` |

---

## Config defaults

| Stage | Model | Effort |
|-------|-------|--------|
| Architect | claude-opus-4-8 | xhigh |
| Plan | claude-opus-4-8 | high |
| Build | claude-sonnet-4-6 | medium |
| Review | claude-sonnet-4-6 | low |

Override any of these at any checkpoint by telling Claude what to change.

---

## Prompts

The prompts for each stage are in `prompts/`. Edit them to customize pipeline behavior for your domain:

| File | Stage | What it controls |
|------|-------|-----------------|
| `prompts/architect.txt` | Stage 1 | How tasks are decomposed |
| `prompts/plan.txt` | Stage 2 | How instructions are written |
| `prompts/build.txt` | Stage 3 | How each task is executed |
| `prompts/review.txt` | Stage 4 | How outputs are validated |

---

## Retry loop

On Review FAIL, Claude shows the issues and remediation guidance. Options:
- **`retry`** — auto-retries Build with remediation injected into prompts
- **`fix [task N]`** — you specify the fix manually
- **`stop`** — end with current outputs

Default max retries: 3. Override: `max [N] retries` at any checkpoint.

---

## Project structure

```
llm-pipeline/
├── skill/
│   └── llm-pipeline.md   ← install this to ~/.claude/skills/
├── prompts/
│   ├── architect.txt
│   ├── plan.txt
│   ├── build.txt
│   └── review.txt
└── README.md
```
