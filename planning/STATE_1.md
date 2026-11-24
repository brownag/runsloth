# State — Orchestration 1

Plan: `planning/EXECUTION_PLAN_1.md` · Template: `planning/PROMPT_TEMPLATE_1.md`
Branch: `feat/package-base` (base `main`)

## Baseline (pre-wave 1)

- [x] `master` renamed to `main`
- [x] `.gitignore` + `planning/` committed on `main` (`docs(planning):`)
- [x] `feat/package-base` created
- Suites: none yet (empty package). First green baseline = 1.1.1 acceptance.
- Tooling: R 4.6.2, reticulate 1.47.0, roxygen2 8.1.1, testthat 3.3.2, rcmdcheck 1.4.0, Python 3.12.3 (`/usr/bin/python3`, no torch), AMD GPUs, no CUDA.

## Wave board

| Wave | Task | Status | Commit |
|---|---|---|---|
| 1 | 1.1.1 Package skeleton, delayed imports, test helpers | done | `7998f6f` |
| 2 | 1.2.1 Interop and GGUF helpers in `R/utils.R` | in progress | |
| 3 | 1.3.1 Release-hygiene pass | pending | |

## Task reports

## 1.1.1

- Status: done. Commit `7998f6f` (code only). `planning/` left uncommitted for the orchestrator.
- Files: `DESCRIPTION` (1-18), `LICENSE` (Apache 2.0 copy), `.Rbuildignore` (1-5), `NAMESPACE` (generated), `R/runsloth-package.R` (1-5), `R/zzz.R` (1-30), `tests/testthat.R` (1-4), `tests/testthat/helper-skip.R` (1-46), `tests/testthat/test-load.R` (1-9), `man/runsloth-package.Rd` (generated).
- Tests: `testthat::test_local(filter='load')` -> FAIL 0, WARN 0, SKIP 0, PASS 2.
- Install: `R CMD INSTALL .` exit 0; `library(runsloth); stopifnot(!py_available(initialize=FALSE))` exit 0.
- roxygen: NAMESPACE has `importFrom(rlang,"%||%")`. DESCRIPTION gained `Config/roxygen2/version: 8.1.1`.
- Deviations: Title and Description per coordinator answer (not the spec's wording). Cache is `.runsloth_test_env` (package-local env in helper-skip.R) holding path or skip reason. `skip_on_cran()` runs first.
- Gotchas for 1.2.1: helpers are `skip_if_no_python()` (returns the path invisibly), `skip_if_no_unsloth()`, `skip_if_no_gpu()`. Use `testthat::` qualified calls. `ensure_unsloth()` is `@noRd`. Python tests skip unless `RUNSLOTH_TEST_PYTHON` or `python3` on PATH resolves.
- Discovered: none.
