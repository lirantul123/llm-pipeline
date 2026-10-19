# Evals

Manual smoke tests to run before every release. Each case says what to type and what must be true for it to pass. Run them in a scratch directory (`mkdir /tmp/llm-pipeline-eval && cd $_ && git init`).

Record results in the release PR: case ID, Claude Code version, pass or fail, and notes.

| ID | Prompt | Must be true |
|----|--------|--------------|
| E1 | `/llm-pipeline Write a Python function is_palindrome(s) with pytest tests` | Stage 0 asks at most 2 questions, or none; 1–2 tasks; files written to disk; review subagent runs `pytest` and quotes the output |
| E2 | `/llm-pipeline Build a small Express API with GET/POST /todos (in-memory) and tests` | Tasks list `files` and `depends_on`; at least one wave runs ≥2 builders in a single message; review is a separate subagent |
| E3 | Run E2, and at Checkpoint 3 say `redo T2, return 201 on POST` | Only T2 is rebuilt; other files unchanged |
| E4 | Make a test fail on purpose before review (edit a test) | Review returns FAIL with evidence; `retry` rebuilds only the failing task; attempt counter shown |
| E5 | Start E2, say `stop` at Checkpoint 2, then in a new session run `/llm-pipeline resume` | Resumes at Checkpoint 2 from `.llm-pipeline/runs/<id>/state.md` |
| E6 | `/llm-pipeline Write a 1-page onboarding guide for new backend engineers` (non-code) | Output written as a Markdown file in the repo or run directory; review checks criteria without inventing test commands |
| E7 | Run in a repo with uncommitted changes | Skill warns before Build and offers to continue or stop; never commits, stashes or resets by itself |
| E8 | `/llm-pipeline go all: add a --version flag to cli.py` | Checkpoints 1–3 are skipped and announced; Review still runs |
| E9 | At Checkpoint 1, say `use haiku for build` | Builder `Agent` calls pass `model: "haiku"`; config table shown with the change |
