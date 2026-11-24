---
id: "0005"
title: "Declare package dependencies only when code uses them"
status: "Accepted"
date: 2026-11-23
authors:
  - "Andrew Gene Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_1"
---

# 5. Declare package dependencies only when code uses them

## Context and Problem Statement

The original package specification lists every package that the finished package will eventually need in Imports and Suggests (for example `stats`, `utils`, ellmer, ollamar, httr2, processx). The package is built incrementally, so most of those dependencies have no users in early milestones. Declaring them up front causes problems:

* An unused Imports entry triggers the `R CMD check` NOTE "Namespaces in Imports field not imported from".
* An uninstalled Suggests entry can fail checks on development machines.
* The dependency list stops matching the code it is supposed to describe.

## Decision Drivers

* Keep `R CMD check` at 0 errors, 0 warnings, and 0 notes at every milestone.
* Make DESCRIPTION an accurate record of what the code needs.
* Keep the install footprint small.

## Considered Options

1. Declare the full target dependency list from the start.
2. Declare each dependency in the same change that first uses it.

## Decision Outcome

Chosen option: 2. A package is added to Imports or Suggests only in the change that first uses it, and is removed when its last use goes away. This applies to base-R packages such as `stats` and `utils` too. Non-base functions are called with their namespace qualified (`utils::`, `stats::`), apart from targeted `@importFrom` entries such as rlang's `%||%`. `NAMESPACE` is generated only by `roxygen2::roxygenise()`.

### Consequences

* **Positive**: The check stays clean at every milestone. DESCRIPTION shows the real dependency surface. Code review catches each new dependency.
* **Negative**: DESCRIPTION knowingly differs from the specification's target list. Contributors must add each dependency as part of the feature that uses it.

## Validation & Compliance

* `rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")` gives 0 errors, 0 warnings, and 0 notes.
* After `roxygen2::roxygenise()`, `git diff --exit-code NAMESPACE man/` shows nothing to regenerate.
