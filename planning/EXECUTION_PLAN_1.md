# Execution Plan 1 — runsloth package base (G1+G2)

Orchestration: 1 · Created: 2026-11-23 · Source: `planning/GOALS.md` (Circled Goal G1+G2), `planning/SPEC.md`

## Goal & Scope

**Goal.** The runsloth package base installs, loads, and checks clean, and its Python-facing helpers are testable on CPU with the system Python and no stub modules. This is the foundation every later module (G3–G10) builds on.

**In scope**

- `DESCRIPTION`, `LICENSE` (Apache 2.0, excluded from the build), `.Rbuildignore`, generated `NAMESPACE`, `R/runsloth-package.R`.
- `R/zzz.R`: package-level Python bindings, `ensure_unsloth()`, delayed imports with the unsloth-first guard, opt-in `py_require()`.
- `R/utils.R`: `as_py_int()`, `as_py_dtype()`, `py_callable_params()`, `validate_py_identifier()`, `resolve_model_device()`, `.find_exported_gguf()`, `.export_gguf_internal()`.
- `tests/testthat.R`, `tests/testthat/helper-skip.R` (`skip_if_no_python()`, `skip_if_no_unsloth()`, `skip_if_no_gpu()`), and unit tests.

**Out of scope (explicit deferrals)**

- Every user-facing module: `R/install.R` (G3), `R/model.R` (G4), `R/chat_templates.R` (G5), `R/train.R` (G6), `R/vision.R` (G7), `R/grpo.R` (G8), `R/infer.R` (G9), `R/hub_ollama.R` + `R/backends.R` (G10).
- `README.md` and `@examples` that use ellmer (G12).
- Checking upstream APIs for drift (G11), and the GPU/ROCm smoke test (G13).
- Python stub modules (deferred to G8/G9, the only goals that need them).
- A dedicated import-order test (dropped; see decision log).
- Suggests other than `testthat` and `withr` (each later goal adds its own).

**Verbatim constraints from the spec**

- "Never initialize Python during library(runsloth) or R CMD check (delay_load = TRUE must hold until an Unsloth function actually accesses Python)."
- "Attach delay_load = list(before_load = ensure_unsloth) when importing trl, transformers, and datasets inside .onLoad()."
- "Omit legacy Config/reticulate blocks that trigger unwanted auto-installs during R CMD check. Support reticulate::py_require() optionally (opt-in via options(runsloth.use_py_require = TRUE) or unsloth_use_managed_python(), guarded by checking whether py_require exists in asNamespace("reticulate"))". (`unsloth_use_managed_python()` itself is G3.)
- "Qualify or import all non-base symbols (utils::flush.console(), stats::setNames(), @importFrom rlang %||%) so R CMD check passes with 0 errors, 0 warnings, and 0 notes on global variables."
- "Generate NAMESPACE and man/*.Rd exclusively via roxygen2::roxygenise()."
- "Every integer hyperparameter ... must be coerced via as.integer()" (implemented by `as_py_int()`).
- `.export_gguf_internal()` passes "tokenizer = object$tokenizer, quantization_method = quant_arg, and maximum_memory_usage = max_memory_usage explicitly by keyword per Unsloth issue #2058"; `.find_exported_gguf()` "ranks .gguf files matching the requested quantization string ahead of intermediate f16 artifacts".

## Decision log

- 2026-11-22 — G1 and G2 form one circled goal (user).
- 2026-11-22 — GPU smoke test retargeted to AMD ROCm (G13), not part of this plan (user).
- 2026-11-22 — Ranking criteria: favor early test coverage and upstream accuracy (user).
- 2026-11-22 — Git: rename `master` to `main`; first commit = `.gitignore` + planning docs; implementation on `feat/package-base`; the user merges (user).
- 2026-11-22 — Planning artifacts are **tracked**, in separate `docs(planning):` commits, never mixed with code commits (user).
- 2026-11-22 — Import-order test dropped: it would mostly test reticulate's own `before_load` hook, and G13 catches unsloth's own import-order warning (user).
- 2026-11-22 — No Python stub modules in this plan. Python-touching helpers are tested in-session against small functions/classes defined with `reticulate::py_run_string()` on the system Python, and skipped when no Python is available (user).
- 2026-11-22 — Testing rule for G4–G10: keep Python-dependent logic separate from plain R logic so routing/validation can be tested without Python (user).
- 2026-11-23 — Workers: Haiku 5.5; escalate to Sonnet 5.5 after one failed retry; Opus orchestrates and reviews (user).
- 2026-11-23 — Suggests added only when used. This plan: `testthat (>= 3.0.0)`, `withr`. This departs from the spec's full Suggests list on purpose (user).
- 2026-11-23 — `LICENSE` holds the full Apache 2.0 text (copied from `R.home("share")/licenses/Apache-2.0`) and is listed in `.Rbuildignore`; `License: Apache License (>= 2)` in DESCRIPTION (orchestrator; CRAN convention for standard licenses).
- 2026-11-23 — `stats` and `utils` are left out of Imports until G5/G9 use them, following the add-when-used rule (orchestrator; avoids an rcmdcheck NOTE). This departs from the spec's Imports list on purpose.
- 2026-11-23 — `RoxygenNote` is whatever the installed roxygen2 (8.1.1) writes, not the spec's 7.3.1 (orchestrator; roxygen rewrites the field).

## Recon log (facts)

- Repo `/home/andrew/AI/runsloth`: branch `master`, no commits, no `.gitignore`, no AGENTS.md, no `docs/decisions/`. Only `planning/SPEC.md` and `planning/GOALS.md` exist.
- R 4.6.2; reticulate 1.47.0 (has `py_require`); roxygen2 8.1.1; testthat 3.3.2; rcmdcheck 1.4.0; cli, rlang, processx, httr2, jsonlite, tibble, devtools, withr installed. ellmer and ollamar are not installed (not needed here).
- System Python: `/usr/bin/python3` 3.12.3 with `venv`; no torch. `uv` at `~/.local/bin/uv`. `RETICULATE_PYTHON` is unset.
- GPUs are AMD (no CUDA). `llama-server`, `llama-cli`, `ollama` are not on PATH.
- Apache 2.0 text: `$(R.home("share"))/licenses/Apache-2.0`.
- No existing code, so there is no reference implementation in the repo. Follow the reticulate vignette "Using reticulate in an R Package" (pattern: top-level `x <- NULL`, then `x <<- reticulate::import(..., delay_load = ...)` in `.onLoad`).

## Hazards

- **H1 — reticulate may provision Python on its own.** With no `RETICULATE_PYTHON` and no configured env, reticulate ≥1.41 may use uv to download and create an ephemeral Python when Python first initializes. Tests must never trigger this. `skip_if_no_python()` must pick an explicit interpreter (`Sys.getenv("RUNSLOTH_TEST_PYTHON")`, else `Sys.which("python3")`), skip if it's empty, and call `reticulate::use_python(path, required = TRUE)` before anything initializes Python. It also calls `testthat::skip_on_cran()`.
- **H2 — Python starts once per R session.** Within one test run, the first test that initializes Python decides the interpreter. Every Python-touching test must call `skip_if_no_python()` first. The load-safety test (`test-load.R`) must not initialize Python and must not depend on running before other tests.
- **H3 — `.onLoad` must stay inert.** No `reticulate::py_*` call in `.onLoad` may initialize Python. `py_require()` only declares requirements, but it stays behind the option *and* behind `exists("py_require", envir = asNamespace("reticulate"))`.
- **H4 — the `torch` proxy.** `as_py_dtype()` must check its input and return `NULL` **before** touching `torch`, so `NULL` and unknown inputs are testable without Python.
- **H5 — Dependency discipline.** Do not add Suggests beyond `testthat` and `withr` (rcmdcheck may error on uninstalled suggests). Do not list `stats` or `utils` in Imports until code uses them: an unused Imports entry triggers the NOTE "Namespaces in Imports field not imported from".
- **H6 — `skip_on_cran()` under rcmdcheck.** rcmdcheck does not set `NOT_CRAN`, so Python tests skip during rcmdcheck and run under `test_local()`. This is expected; report the skip counts.

## Wave table

| Wave | Task | Title | Depends on | Files (disjoint within wave) |
|---|---|---|---|---|
| — | pre | Orchestrator: branch setup, baseline | — | `.gitignore`, `planning/*` |
| 1 | 1.1.1 | Package skeleton, delayed imports, test helpers | pre | DESCRIPTION, LICENSE, .Rbuildignore, NAMESPACE, R/runsloth-package.R, R/zzz.R, tests/testthat.R, tests/testthat/helper-skip.R, tests/testthat/test-load.R, man/ |
| 2 | 1.2.1 | Interop and GGUF helpers in `R/utils.R` | 1.1.1 | R/utils.R, tests/testthat/test-utils.R, NAMESPACE, man/ |
| 3 | 1.3.1 | Release-hygiene pass: roxygen, tests, rcmdcheck 0/0/0 | 1.2.1 | any file created in 1.1.1 / 1.2.1 (fixes only) |

Each wave has one task, so no worktrees are needed. The waves are sequential because each one needs the previous wave's files.

## Pre-wave steps (orchestrator)

1. `git branch -m master main`.
2. Write `.gitignore` (`.Rproj.user/`, `.Rhistory`, `.RData`, `.development/`, `*.tar.gz`, `runsloth.Rcheck/`).
3. Commit `.gitignore` + `planning/` as `docs(planning): add spec, goals, and execution plan 1`.
4. `git switch -c feat/package-base`.
5. Record the baseline in STATE_1.md (empty package: no suites yet; tool versions from the recon log).

## Task specs

### 1.1.1 — Package skeleton, delayed imports, test helpers

- **Repo:** `/home/andrew/AI/runsloth` (branch `feat/package-base`)
- **Depends on:** pre
- **Files in scope**
  - Can create: `DESCRIPTION`, `LICENSE`, `.Rbuildignore`, `R/runsloth-package.R`, `R/zzz.R`, `tests/testthat.R`, `tests/testthat/helper-skip.R`, `tests/testthat/test-load.R`; generated `NAMESPACE`, `man/*.Rd`.
  - Temp: `.development/` (gitignored).
  - Off-limits: everything else, especially `planning/` (except your todo file and STATE_1.md report) and `R/utils.R`.
- **Spec**
  - `DESCRIPTION`: `Package: runsloth`, `Version: 0.1.0`, a Title and Description that say the package wraps Python's unsloth via reticulate. `Authors@R`: `person("Andrew Gene", "Brown", role = c("aut", "cre"), email = "brown.andrewg@gmail.com")`. `License: Apache License (>= 2)`, `Encoding: UTF-8`, `Depends: R (>= 4.1.0)`, `Imports: cli, reticulate (>= 1.34.0), rlang`, `Suggests: testthat (>= 3.0.0), withr`, `Config/testthat/edition: 3`, `Roxygen: list(markdown = TRUE)`. **No** `Config/reticulate` field.
  - `LICENSE`: copy `file.path(R.home("share"), "licenses", "Apache-2.0")` verbatim. `.Rbuildignore`: `^LICENSE$`, `^planning$`, `^\.development$`, `^.*\.Rproj$`, `^\.Rproj\.user$`.
  - `R/runsloth-package.R`: `"_PACKAGE"` doc block with `@importFrom rlang %||%` and `@keywords internal`.
  - `R/zzz.R`:
    - Top-level `unsloth <- NULL; trl <- NULL; datasets <- NULL; transformers <- NULL; torch <- NULL; inspect <- NULL`.
    - Internal `ensure_unsloth()`: forces the unsloth import (`invisible(unsloth$FastLanguageModel)`), documented `@noRd`.
    - `.onLoad(libname, pkgname)`:
      - `unsloth`, `torch` and `inspect` via `reticulate::import(..., delay_load = TRUE)`.
      - `trl`, `transformers` and `datasets` via `delay_load = list(before_load = function() ensure_unsloth())`.
      - Then, only if `isTRUE(getOption("runsloth.use_py_require", FALSE)) && exists("py_require", envir = asNamespace("reticulate"))`, call `reticulate::py_require("unsloth")`.
    - Assign bindings with `<<-`.
  - `tests/testthat.R`: standard `library(testthat); library(runsloth); test_check("runsloth")`.
  - `tests/testthat/helper-skip.R`:
    - `skip_if_no_python()` per Hazard H1. Cache the result so later calls skip or pass the same way.
    - `skip_if_no_unsloth()`: calls `skip_if_no_python()`, then skips unless `reticulate::py_module_available("unsloth")`.
    - `skip_if_no_gpu()`: calls `skip_if_no_unsloth()`, then skips unless torch reports `cuda$is_available()` (true on ROCm builds too) — import torch via `reticulate::import("torch")` inside the helper.
  - `tests/testthat/test-load.R`:
    - (a) Loading the package does not initialize Python: assert `!reticulate::py_available(initialize = FALSE)` **only if** no earlier test initialized it. Use `skip_if(reticulate::py_available(initialize = FALSE), "Python already initialized by another test")`.
    - (b) The bindings exist in the namespace: `exists("trl", envir = asNamespace("runsloth"))`.
- **Anchors:** none (new files). Pattern reference: reticulate vignette "Using reticulate in an R Package" (`vignette("package", package = "reticulate")`), section "Delay load".
- **Acceptance**
  - `Rscript -e "roxygen2::roxygenise()"` succeeds and NAMESPACE contains `importFrom(rlang,"%||%")`.
  - `R CMD INSTALL . && Rscript -e 'library(runsloth); stopifnot(!reticulate::py_available(initialize = FALSE))'` exits 0.
  - `Rscript -e "testthat::test_local(filter = 'load')"` shows 0 failures.

### 1.2.1 — Interop and GGUF helpers in `R/utils.R`

- **Repo:** `/home/andrew/AI/runsloth` (branch `feat/package-base`)
- **Depends on:** 1.1.1 (read its STATE_1.md report for helper names and gotchas)
- **Files in scope**
  - Can create: `R/utils.R`, `tests/testthat/test-utils.R`; regenerated `NAMESPACE`, `man/`.
  - Temp: `.development/`.
  - May regenerate (via `roxygenise()` only): `NAMESPACE`, `man/`.
  - Off-limits: all other files from 1.1.1 (report in `## Discovered` if one needs changing).
- **Spec** (all internal, `@noRd` or `@keywords internal`; use `cli::cli_abort()` for errors, with `{.arg}` / `{.val}` markup)
  - `as_py_int(x, arg = rlang::caller_arg(x))`:
    - `NULL` → `NULL`.
    - Otherwise it must be numeric, finite, and whole (`x == round(x)`) or it aborts. Never silently truncate `2.5`.
    - Returns `as.integer(x)`.
  - `validate_py_identifier(name)`:
    - Must be a length-1, non-NA string matching `^[A-Za-z_][A-Za-z0-9_]*$` and not in a hard-coded Python keyword vector (the 35 from `keyword.kwlist` in Python 3.12).
    - Aborts otherwise; returns `invisible(name)`.
  - `as_py_dtype(x)`:
    - `NULL` → `NULL`.
    - Validates `x` against `c("float16", "fp16", "bfloat16", "bf16")` **before** touching `torch` (Hazard H4), aborting on anything else.
    - Then returns `torch$float16` or `torch$bfloat16`.
  - `py_callable_params(fn)`: `reticulate::py_to_r(reticulate::import_builtins()$list(inspect$signature(fn)$parameters$keys()))` → character vector.
  - `resolve_model_device(model)`:
    - Tries `model$device` first, then the device of the first parameter (`reticulate::iter_next(reticulate::as_iterator(model$parameters()))$device`), else `"cpu"`.
    - Returns a string via `reticulate::py_str()`, or `"cpu"`. Wrap each attempt in `tryCatch`.
  - `.find_exported_gguf(save_dir, quantization_method)`:
    - Lists `\\.gguf$` files recursively under `save_dir`.
    - Ranks them: (1) basename contains the quantization string, case-insensitive, with `-` and `_` treated as the same; (2) other non-`f16`/`bf16` files; (3) `f16`/`bf16` files.
    - Returns `normalizePath()` of the best match, or `NULL` if there are none.
  - `.export_gguf_internal(object, save_dir, quantization_method = "q4_k_m", max_memory_usage = 0.75)`:
    - `quant_arg` is `as.list(quantization_method)` when the length is greater than 1, else the scalar.
    - Calls `object$model$save_pretrained_gguf(save_dir, tokenizer = object$tokenizer, quantization_method = quant_arg, maximum_memory_usage = max_memory_usage)`, all by keyword except `save_dir`.
    - Then `.find_exported_gguf(save_dir, quantization_method[[1]])`. Aborts with a `{.file}` message if that returns `NULL`; otherwise returns the path.
- **Tests (`tests/testthat/test-utils.R`)**
  - Plain R, no Python:
    - `as_py_int`: NULL, `2` → `2L`, vector, `2.5` errors, `NA` errors, `"a"` errors.
    - `validate_py_identifier`: valid, leading digit, hyphen, `"class"`, length-2, NA.
    - `as_py_dtype`: `NULL` → `NULL`; `"float64"` errors.
    - `.find_exported_gguf` with `withr::local_tempdir()`:
      - `model-F16.gguf` + `model-Q4_K_M.gguf` → the Q4 file for `"q4_k_m"`;
      - only f16 → the f16 file;
      - empty dir → `NULL`;
      - a nested subdir is found.
    - `.export_gguf_internal` with an **R list stand-in**: `object <- list(model = list(save_pretrained_gguf = function(save_dir, tokenizer, quantization_method, maximum_memory_usage) { file.create(file.path(save_dir, "m-Q8_0.gguf")) }), tokenizer = "tok")`.
      - Assert the path is returned and the arguments arrive by keyword (capture them in an environment).
      - Assert that `c("q4_k_m", "q8_0")` arrives as a list.
  - Python, each starting with `skip_if_no_python()`:
    - `py_callable_params` on a `def f(a, b=1, *args, c, **kw)` defined via `reticulate::py_run_string()` → `c("a", "b", "args", "c", "kw")`.
    - `resolve_model_device` on a Python class with `device = "meta"` → `"meta"`, and on a bare `object()` → `"cpu"`.
- **Anchors:** `R/zzz.R` bindings `inspect`, `torch` (top of file); `tests/testthat/helper-skip.R` `skip_if_no_python`.
- **Acceptance**
  - `Rscript -e "roxygen2::roxygenise()"` succeeds.
  - `Rscript -e "testthat::test_local(filter = 'utils')"` shows 0 failures. Python tests pass (not skip) on this host, since `/usr/bin/python3` exists.

### 1.3.1 — Release-hygiene pass

- **Repo:** `/home/andrew/AI/runsloth` (branch `feat/package-base`)
- **Depends on:** 1.2.1
- **Files in scope**
  - Must edit (fixes only): files created in 1.1.1 / 1.2.1.
  - Temp: `.development/` (put rcmdcheck output here).
  - Off-limits: adding new exported functions, adding Suggests, `planning/` (except your todo and report).
- **Spec**
  1. Run the three commands below.
  2. Fix every error, warning, and note that the package source causes (undeclared globals, missing imports, Rd problems, `.Rbuildignore` gaps).
  3. Do **not** silence notes by adding `globalVariables()` for symbols that are real bindings. Do **not** add Suggests.
  4. If a note is environmental and can't be fixed in the source (e.g. "checking for future file timestamps"), record it under `## Discovered` instead of working around it.
  5. Confirm the load-safety check once more from the installed tarball.
- **Anchors:** whatever rcmdcheck names. Do not read files that aren't implicated.
- **Acceptance (all must pass)**
  - `Rscript -e "roxygen2::roxygenise()"` followed by `git diff --exit-code NAMESPACE man/` (nothing left to regenerate).
  - `Rscript -e "testthat::test_local()"` → 0 failures. Report pass and skip counts.
  - `Rscript -e "rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'warning', check_dir = '.development')"` → 0 errors, 0 warnings, 0 notes.
  - `R CMD INSTALL . && Rscript -e 'library(runsloth); stopifnot(!reticulate::py_available(initialize = FALSE))'` exits 0.

## Wave-end verification (orchestrator, serial)

After each wave: re-run the task's acceptance commands, then `Rscript -e "testthat::test_local()"`. After wave 3, also run the full rcmdcheck command from 1.3.1. Commits use the Conventional Commits format, one per verified task, on `feat/package-base`. Planning-state updates go in separate `docs(planning):` commits.
