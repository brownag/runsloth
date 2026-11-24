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
| 2 | 1.2.1 Interop and GGUF helpers in `R/utils.R` | done | `849d6b9` |
| 3 | 1.3.1 Release-hygiene pass | done | `dfad6df` |

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

## 1.2.1

- Status: done. Commit `849d6b9` (code only). `planning/` left uncommitted.
- Files: `R/utils.R` (1-127, new), `tests/testthat/test-utils.R` (1-130, new). `NAMESPACE` and `man/` unchanged by roxygen (all helpers `@noRd`, no exports).
- Tests: `testthat::test_local(filter='utils')` -> FAIL 0, WARN 0, SKIP 0, PASS 36 (incl. 2 Python tests, not skipped). `test_local(filter='load')` -> FAIL 0, PASS 2.
- Acceptance: `roxygen2::roxygenise()` ran clean.
- Deviations: per coordinator answers, `as_py_int` accepts numeric vectors (elementwise), rejects logical; `.find_exported_gguf` case-insensitive f16/bf16 rank, sorted tie-break. One test expectation of mine was corrected during the run (q8_0 ranks the Q4 file above F16 per the spec's rank 2 vs 3); code unchanged.
- Gotchas for dependent tasks: `NOT_CRAN` is set by `test_local()` (`local_assume_not_on_cran`), so Python tests run there. `.py_keywords` vector is in `R/utils.R`. `as_py_dtype` references `torch` only after validation; a real float16 call needs torch installed (untested here).
- Discovered: none.

## 1.3.1

- Status: done. Verify-plus-one-test-cleanup; no package behavior changed.
- Files: `tests/testthat/test-utils.R` (lines 40-43 removed, duplicate `.find_exported_gguf(dir, "q4_k_m")` expectation).
- Code commit: `dfad6df` (subject `test(utils): drop duplicate GGUF ranking expectation`).
- `test_local(filter='utils')` -> FAIL 0, WARN 0, SKIP 0, PASS 35.
- `roxygen2::roxygenise()` + `git diff --exit-code NAMESPACE man/` -> clean (no-op).
- `test_local()` -> FAIL 0, WARN 0, SKIP 0, PASS 37 (full suite; prior count 38 included the removed duplicate).
- rcmdcheck (`error_on='warning'`, check_dir `.development`) -> `0 errors | 0 warnings | 0 notes`.
- Under check (`testthat.Rout`): FAIL 0, WARN 0, SKIP 2 (On CRAN, `test-utils.R` Python tests, H6), PASS 34.
- `R CMD INSTALL .` + load-safety check -> exit 0 (`LOAD_SAFE_OK`).
- Deviations: none from approved plan. Reported PASS counts changed from 38 to 37 because one duplicate expectation was removed.
- Discovered: none.
- Gotchas: Python tests skip under rcmdcheck (H6), so run `test_local()` for full Python coverage.

## Orchestration 1 — final verification (orchestrator)

- `roxygenise()` no-op; `test_local()` FAIL 0 | SKIP 0 | PASS 37; rcmdcheck `--no-manual` 0 errors | 0 warnings | 0 notes (Python tests skip under check per H6); installed load-safety check exit 0.
- Branch `feat/package-base` ready for the user to merge into `main`. Nothing pushed.
