---
id: "0003"
title: "Convert types and pass keywords explicitly at the R-to-Python boundary"
status: "Accepted"
date: 2026-11-22
authors:
  - "Andrew Gene Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_1"
---

# 3. Convert types and pass keywords explicitly at the R-to-Python boundary

## Context and Problem Statement

reticulate's default conversions don't match what Python ML APIs expect:

* R doubles become Python `float`, so `r = 16` arrives as `16.0` and integer-only parameters fail or misbehave.
* Length-1 R vectors become Python scalars, so `c("q_proj")` arrives as a string rather than a list.
* Positional arguments break when upstream inserts or reorders parameters. Unsloth issue #2058 is one example, from the GGUF export path.

These failures often show up deep inside the Python stack, far from the R call that caused them.

## Decision Drivers

* Give R users predictable behavior no matter how they write numbers or vectors.
* Fail early in R, with clear errors, rather than late in Python.
* Hold up against upstream signature drift in fast-moving libraries (unsloth, trl, transformers).

## Considered Options

1. Rely on reticulate's default conversions and pass arguments positionally.
2. Convert values ad hoc at each call site.
3. Route all boundary conversions through shared internal helpers, and pass every non-leading argument by keyword.

## Decision Outcome

Chosen option: 3. Every Python call site in the package follows these rules:

* Integer parameters go through `as_py_int()`. It passes `NULL` through, rejects non-numeric, non-finite, and fractional values, and never truncates silently.
* Parameters that expect a Python list are wrapped with `as.list()`, so single-item vectors don't collapse into scalars.
* Dtype strings go through `as_py_dtype()`, which validates the string before it touches `torch`.
* Names used in generated Python code go through `validate_py_identifier()`.
* Python callables are called with keyword arguments. Where upstream signatures drift, check the accepted parameters with `py_callable_params()` instead of assuming them.

### Consequences

* **Positive**: Wrong inputs raise clear R errors right where they are passed. Wrapper code is less coupled to upstream positional order. Conversion rules are tested once, in one place.
* **Negative**: Call sites are more verbose. Contributors have to know about the helpers and use them every time, so review must check for this.

## Validation & Compliance

* `tests/testthat/test-utils.R` covers the helpers, including errors on fractional and `NA` integers and list wrapping of multi-value arguments.
* Review rule: new Python calls must use the helpers above and keyword arguments.
