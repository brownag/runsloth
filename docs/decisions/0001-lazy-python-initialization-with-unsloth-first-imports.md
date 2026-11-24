---
id: "0001"
title: "Initialize Python lazily and import unsloth before its dependents"
status: "Accepted"
date: 2026-11-22
authors:
  - "Andrew Gene Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_1"
---

# 1. Initialize Python lazily and import unsloth before its dependents

## Context and Problem Statement

runsloth wraps Python libraries (unsloth, trl, transformers, datasets, torch) through reticulate. Python can be initialized only once per R session, and the first initialization fixes which interpreter is used. If loading the package initializes Python, users can no longer choose an environment, `R CMD check` needs a working Python stack, and loading takes several seconds.

unsloth also patches trl, transformers, and peft when it is imported. If one of those libraries is imported first, the patches don't take effect and training silently loses Unsloth's optimizations.

## Decision Drivers

* `library(runsloth)` and `R CMD check` must work on machines with no Python or GPU.
* Users keep control of interpreter selection until the first call that needs Python.
* Import order must be correct no matter which module the user's code touches first.

## Considered Options

1. Import the modules eagerly in `.onLoad()`.
2. Import the modules inside each user-facing function when it is called.
3. Bind package-level module proxies in `.onLoad()` with `reticulate::import(..., delay_load = ...)`, and give the dependents a `before_load` hook that forces unsloth first.

## Decision Outcome

Chosen option: 3. Package-level bindings (`unsloth`, `trl`, `transformers`, `datasets`, `torch`, `inspect`) start as `NULL` and are assigned delayed proxies in `.onLoad()`. `trl`, `transformers`, and `datasets` are imported with `delay_load = list(before_load = function() ensure_unsloth())`, so the first access to any of them imports unsloth first. Nothing in `.onLoad()` may initialize Python.

### Consequences

* **Positive**: Loading the package and running the check stay Python-free. Import order is enforced in one place instead of at every call site. All modules share one set of bindings.
* **Negative**: Errors from a missing Python module surface at first use, not at load. Any new Python dependency that unsloth patches must be added with the same `before_load` hook. The ordering guarantee depends on reticulate's `before_load` behavior.

## Validation & Compliance

* `tests/testthat/test-load.R` asserts that loading the package does not initialize Python.
* `library(runsloth); stopifnot(!reticulate::py_available(initialize = FALSE))` must succeed from an installed build.
* Review rule: no `reticulate::py_*` call in `.onLoad()` may initialize Python. The only allowed one is `py_require()`, which just declares requirements (see [0002](0002-opt-in-python-environment-provisioning.md)).
