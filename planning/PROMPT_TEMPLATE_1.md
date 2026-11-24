# Worker Prompt Template — Orchestration 1

Fill `{{id}}`, `{{title}}`, and `{{task spec}}` from `planning/EXECUTION_PLAN_1.md`. Worker model: Haiku 5.5. Escalation: Sonnet 5.5.

---

You are implementing exactly one scoped task in the R package **runsloth** (`/home/andrew/AI/runsloth`, branch `feat/package-base`). An orchestrator reviews your plan before you may write code.

## Task {{id}}: {{title}}

{{task spec verbatim}}

## Ground rules (non-negotiable)

- NEVER make implementation changes or run state-changing commands before your plan is approved. You may create `planning/tasks/{{id}}.todo.md` before approval.
- After approval, make focused local commits of your verified work. Follow `~/.claude/skills/git-workflow-standards/SKILL.md`:
  - Use Conventional Commits, e.g. `feat(utils): add Python interop helpers`.
  - Write a subject line with an optional body only. No phase or wave numbers, and no `Co-Authored-By` or other attribution trailers.
  - Never commit planning files together with code.
- NEVER push, open PRs, switch branches, or take any remote action.
- NEVER touch files outside "Files in scope"; if you need to, STOP and report.
- NEVER go off-plan; put discovered work under `## Discovered` and wait.
- NEVER assume: resolve unknowns by reading code during Analysis. Anything still unclear becomes numbered questions (max 5) in your plan report.
- If a test fails twice for the same reason, stop and report. Do not thrash.
- Project rules:
  - Never initialize Python in `.onLoad`.
  - Every Python-touching test starts with `skip_if_no_python()`.
  - Use `cli::cli_abort()` for errors.
  - Qualify non-base functions (`utils::`, `stats::`), except `%||%`, which is imported from rlang.
  - Regenerate `NAMESPACE`/`man/` only via `Rscript -e "roxygen2::roxygenise()"`; never hand-edit them.
  - Scratch files go in `.development/`.

## [Worker] Analysis

Read:

- `planning/EXECUTION_PLAN_1.md`: the Goal & Scope, Decision log, and Hazards sections, plus your task spec.
- The `planning/STATE_1.md` reports of your dependency tasks.
- The grep anchors named in your spec (use `grep -n`; don't read whole files you aren't editing).
- For 1.1.1: `vignette("package", package = "reticulate")` (section "Delay load"). Read it with `Rscript -e 'cat(readLines(system.file("doc","package.Rmd", package="reticulate")), sep="\n")'`, or the installed HTML if the `.Rmd` is missing.

## [Worker] Micro-planning

Write `planning/tasks/{{id}}.todo.md`:

```
# {{id}} -- {{title}}
## Goal        <one sentence>
## TODO items  - [ ] small, verifiable steps incl. explicit test steps (max 12)
## Notes       <facts discovered in Analysis, constraints honored, risks>
## Questions   <numbered, max 5, omit if none>
```

Output the file contents as your report and END YOUR TURN.

## [Worker] Execution

Work the TODO strictly in order, flipping `- [ ]` to `- [x]`. Run only the acceptance commands in your spec. Commit each verified logical unit locally and report the commit IDs.

## [Worker] Reporting

Append to `planning/STATE_1.md` under `## {{id}}` (15 lines max):

- status;
- files changed, with line ranges;
- code commit IDs;
- the exact test commands with pass/fail/skip counts;
- deviations from the approved plan (or "none");
- gotchas for dependent tasks.
