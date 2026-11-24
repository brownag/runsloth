---
id: "0004"
title: "Test Python-facing code against a real interpreter, without stub modules"
status: "Accepted"
date: 2026-11-22
authors:
  - "Andrew Gene Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_1"
---

# 4. Test Python-facing code against a real interpreter, without stub modules

## Context and Problem Statement

Most of runsloth's behavior lives in Python libraries that need a GPU and gigabytes of dependencies. Running the real stack in routine tests is impractical. Fake Python packages (stub modules shaped like unsloth or trl) would let tests run, but they encode guesses about upstream APIs, drift silently, and need upkeep.

reticulate adds two hazards:

* Python initializes once per session, so whichever test runs first picks the interpreter.
* With no interpreter configured, reticulate may download and provision one on its own.

## Decision Drivers

* Get the most test coverage possible on CPU-only machines with only the system Python.
* Tests must never install or download an interpreter.
* Avoid test doubles that can drift from the real upstream APIs.

## Considered Options

1. Stub Python modules that mirror the upstream APIs.
2. Real-stack tests only, run on GPU hosts.
3. Layered testing. Keep plain R logic free of Python and test it everywhere. Test thin Python-facing helpers against small functions and classes defined in-session on a real interpreter. Leave full-stack behavior to a separate GPU smoke test.

## Decision Outcome

Chosen option: 3. The project follows these rules:

* Routing, validation, and argument handling are written as plain R functions that can be tested without Python. Python-dependent code stays a thin layer on top.
* Python-facing tests define their fixtures with `reticulate::py_run_string()` on a real interpreter. They don't use stub packages, and R-list stand-ins are acceptable for duck-typed objects.
* Every Python-touching test starts with `skip_if_no_python()`. It picks an interpreter explicitly, from `RUNSLOTH_TEST_PYTHON` or else `python3` on `PATH`, binds it with `use_python(required = TRUE)` before anything initializes Python, caches the result, and skips when none is found. It also skips on CRAN.
* `skip_if_no_unsloth()` and `skip_if_no_gpu()` gate tests on the heavier tiers.
* Tests must not depend on the order they run in. In particular, the load-safety test skips if another test has already initialized Python.

### Consequences

* **Positive**: Fast, honest tests on ordinary machines. No stub code to maintain. Reticulate never provisions an interpreter during tests.
* **Negative**: Under `R CMD check` (where `NOT_CRAN` is unset) the Python-facing tests skip, so they only run under `testthat::test_local()` or in CI with `NOT_CRAN=true`. Upstream integration bugs surface only in the GPU smoke test. Stub modules may be introduced later for specific features that cannot be tested otherwise. If so, a new ADR should supersede this one.

## Validation & Compliance

* `tests/testthat/helper-skip.R` defines the skip helpers.
* `testthat::test_local()` must run the Python-facing tests (not skip them) on a host with `python3`.
