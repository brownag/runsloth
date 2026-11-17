# runsloth Agent Guide

## Quick Start

- Generate `NAMESPACE` and help pages: `make document`
- Run all tests: `make test`
- Run package check: `make check`
- Build a source tarball outside the repository: `make build`
- Install into the active R library: `make install`

## Find Things

- `R/` — package implementation, organized by model, training, inference, and backend workflows.
- `tests/testthat/` — offline contract tests and guarded Python integration tests.
- `man/` and `NAMESPACE` — generated help pages and exports; update source roxygen comments, then run `make document`.
- `DESCRIPTION` — package metadata and R dependencies.
- `README.md` — user setup and workflow guide.
- `planning/` — separately versioned planning artifacts and grounding specification.

## Workflows

- Keep public documentation in roxygen comments next to the function; regenerate with `make document`.
- Run the relevant targeted test while iterating, then `make test`.
- Use `make check` for package build/check with unavailable optional Suggests allowed.
- Package loading must not install or initialize Python. Python environment setup is an explicit user action via `install_unsloth()` and reticulate configuration.
- Keep tests offline and CPU-safe; mark Python/GPU-dependent integration tests with appropriate skips.
- For implementation tasks, use the repository's plan-first workflow and focused Conventional Commits. Keep planning-only commits separate in `planning/`.

## Infrastructure

- Main implementation language: R (minimum version in `DESCRIPTION`).
- Build/test targets and output location: `Makefile`; source tarballs are written under `/tmp/opencode/runsloth`.
- Optional Python integrations are managed through `reticulate`; package load itself is Python-lazy.
- `Makefile` and `AGENTS.md` are development files excluded from source package builds.

## References

- User-facing setup and examples: `README.md`.
- Package API: `man/` and `NAMESPACE`.
- Grounding requirements and orchestration history: `planning/`.
- Agent onboarding workflow: `/home/andrew/.agents/skills/agent-onboarding/SKILL.md`.
- Makefile workflow: `/home/andrew/.agents/skills/makefile-development-workflow/SKILL.md`.
- Documentation consistency workflow: `/home/andrew/.agents/skills/doc-consistency/SKILL.md`.
