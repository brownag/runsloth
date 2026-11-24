# Architecture Decision Records

These records hold enduring architecture decisions for runsloth. Each one must meet at least two of these criteria:

* expensive to reverse;
* sets a pattern later work must follow;
* cuts across modules;
* accepts explicit trade-offs.

Process choices, task logs, and local helper details are not recorded here.

| ID | Title | Status | Date | Supersedes | Superseded By | Context |
|---|---|---|---|---|---|---|
| [0001](0001-lazy-python-initialization-with-unsloth-first-imports.md) | Initialize Python lazily and import unsloth before its dependents | Accepted | 2026-11-22 | - | - | Execution Plan 1 |
| [0002](0002-opt-in-python-environment-provisioning.md) | Make automatic Python environment provisioning opt-in | Accepted | 2026-11-22 | - | - | Execution Plan 1 |
| [0003](0003-explicit-types-and-keywords-at-the-python-boundary.md) | Convert types and pass keywords explicitly at the R-to-Python boundary | Accepted | 2026-11-22 | - | - | Execution Plan 1 |
| [0004](0004-test-python-code-against-a-real-interpreter-without-stubs.md) | Test Python-facing code against a real interpreter, without stub modules | Accepted | 2026-11-22 | - | - | Execution Plan 1 |
| [0005](0005-declare-dependencies-only-when-used.md) | Declare package dependencies only when code uses them | Accepted | 2026-11-23 | - | - | Execution Plan 1 |
