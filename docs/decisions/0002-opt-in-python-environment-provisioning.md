---
id: "0002"
title: "Make automatic Python environment provisioning opt-in"
status: "Accepted"
date: 2026-11-22
authors:
  - "Andrew Gene Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_1"
---

# 2. Make automatic Python environment provisioning opt-in

## Context and Problem Statement

reticulate can provision Python on its own. A `Config/reticulate` field in DESCRIPTION, or a `reticulate::py_require()` call, makes reticulate create an ephemeral environment via uv the first time Python initializes. That suits pure-Python dependencies, but unsloth needs a torch build that matches the GPU stack (a specific CUDA or ROCm wheel), with xformers and unsloth_zoo pinned to compatible versions. An automatic install can pick the wrong torch build, override a GPU environment the user built carefully, or fail during `R CMD check` and in air-gapped sessions.

## Decision Drivers

* Never install or download anything during package load or `R CMD check`.
* Respect environments that users have already set up for their GPU.
* Still offer the modern reticulate workflow to users who want it.

## Considered Options

1. Declare the requirements in `Config/reticulate`, the legacy approach.
2. Call `reticulate::py_require()` unconditionally in `.onLoad()`, the current reticulate guidance.
3. Leave provisioning out by default. Offer `py_require()` behind an explicit opt-in, and offer an explicit installer for managed virtualenv or conda environments.

## Decision Outcome

Chosen option: 3. DESCRIPTION has no `Config/reticulate` field. `.onLoad()` calls `reticulate::py_require("unsloth")` only when `options(runsloth.use_py_require = TRUE)` is set and the installed reticulate exports `py_require`. An explicit installer and a managed-Python helper are the supported ways to provision an environment.

### Consequences

* **Positive**: `R CMD check` and plain loads never trigger installs. GPU-specific environments are left alone. Users of older reticulate releases are unaffected.
* **Negative**: New users need an extra setup step before the first call works. The package must clearly guide that step, for example with doctor and installer functions and clear error messages.

## Validation & Compliance

* DESCRIPTION must not contain `Config/reticulate`.
* `rcmdcheck::rcmdcheck(args = "--no-manual")` must give 0 errors, 0 warnings, and 0 notes on a machine without unsloth installed.
* Tests must never let reticulate provision its own interpreter (see [0004](0004-test-python-code-against-a-real-interpreter-without-stubs.md)).
