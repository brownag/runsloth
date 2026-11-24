# Project Goals (`planning/GOALS.md`)

Last Updated: 2026-11-22
Source State: planning/SPEC.md (no STATE_N.md yet; repo has no commits)

Custom ranking criteria (agreed): favor early test coverage; favor upstream accuracy.

Host facts: R 4.6.2, reticulate 1.47.0, roxygen2/testthat/rcmdcheck/processx/httr2 installed;
ellmer and ollamar not installed; system Python has no torch; GPUs are AMD (no CUDA);
`llama-server`, `llama-cli`, `ollama` not on PATH.

## Circled Goal (Active)

- **[G1+G2]** The runsloth package base installs, loads, and checks clean; Python-touching helpers are testable on CPU with the system Python and no stub modules.
  - Why now: Every other goal depends on the package base (DESCRIPTION, `R/zzz.R` import order, `R/utils.R` helpers). Setting the test pattern now keeps G4–G10 testable without a GPU (custom criterion: early test coverage).
  - Scope:
    - `DESCRIPTION`, `LICENSE` (Apache 2.0), `.Rbuildignore`, generated `NAMESPACE`, `R/runsloth-package.R` (`@importFrom rlang %||%`).
    - `R/zzz.R`: NULL bindings; `ensure_unsloth()`; `unsloth`/`torch`/`inspect` with `delay_load = TRUE`; `trl`/`transformers`/`datasets` with `delay_load = list(before_load = ensure_unsloth)`; opt-in `py_require()` behind `options(runsloth.use_py_require = TRUE)` and a capability check.
    - `R/utils.R`: `as_py_int()`, `as_py_dtype()`, `py_callable_params()`, `validate_py_identifier()`, `resolve_model_device()`, `.find_exported_gguf()`, `.export_gguf_internal()`.
    - `tests/testthat.R`, `tests/testthat/helper-skip.R` (`skip_if_no_python()`, `skip_if_no_unsloth()`, `skip_if_no_gpu()`).
  - Testing rule (2026-11-22, applies to G4–G10): keep Python-dependent logic separate from plain R logic. Argument-routing logic takes parameter-name vectors as plain R inputs (e.g. `route_sft_args(config_params, trainer_params, args)`) so it can be unit-tested with mocks and no Python. Only G8 (GRPO reward bridge) and G9 (streaming deadlock guard) build minimal Python stubs, scoped to those goals.
  - Dropped (2026-11-22): a dedicated import-order test. It would mostly test reticulate's own `before_load` hook, and unsloth's own warning about import order is caught by the G13 smoke test.
  - Exit criteria:
    - `Rscript -e "roxygen2::roxygenise()"` leaves NAMESPACE/man in sync.
    - After `R CMD INSTALL`, a clean `Rscript` subprocess runs `library(runsloth)` and `reticulate::py_available(initialize = FALSE)` stays `FALSE`.
    - Plain-R unit tests pass for `as_py_int`, `as_py_dtype(NULL)`, `validate_py_identifier`, `.find_exported_gguf` (quant match ranked above f16).
    - In-session test (skipped without Python): `py_callable_params()` returns the parameter names of a function defined in standard-library Python.
    - `rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")` reports 0 errors, 0 warnings, 0 notes.
  - First action: Write `DESCRIPTION` and `R/zzz.R`, run `roxygenise()`, then confirm in a clean subprocess that `library(runsloth)` does not initialize Python.

## Sequenced Goals (Dependency DAG)

- **[G11]** The spec's upstream API assumptions have been checked against current releases (Nov 2026): unsloth / unsloth_zoo (incl. ROCm support status), TRL (SFTConfig/SFTTrainer/GRPOConfig kwargs beyond v0.25), reticulate `py_require`, ellmer `chat_openai_compatible`, llama-server `/health` and `--jinja`. Differences are recorded in `planning/UPSTREAM_DRIFT.md`, and the TRL parameter-list test fixtures are updated to match.
  - Depends on: none (can run in parallel with G1+G2). Promoted per the upstream-accuracy criterion; gates G4–G10 and G13.
- **[G4]** `R/model.R`: `unsloth_load_model()` (at most one of the 4-bit, 8-bit, or full fine-tuning flags; dtype mapping), `unsloth_add_tokens()` (rejected after LoRA), `unsloth_add_lora()`, with plain-R validation tested without Python.
  - Depends on: G1+G2, G11
- **[G3]** `R/install.R`: `install_unsloth()` (xformers opt-in, conda vs virtualenv activation hint, `upgrade = TRUE` path, ROCm torch option), `unsloth_use_managed_python()`, `unsloth_doctor()` (reports CUDA **or** ROCm/HIP).
  - Depends on: G1+G2, G11
- **[G5]** `R/chat_templates.R`: list, set and apply templates (dynamic `conversations_col`, `standardize_data_formats` with fallback); `unsloth_train_on_responses_only()` passes delimiters only when given; Gemma ZeroDivisionError caveat documented.
  - Depends on: G4
- **[G6]** `R/train.R`: `as_hf_dataset()` handles 1-row data; `unsloth_build_trainer()` routes args by inspecting signatures, with argument routing as a plain-R function tested against old and new TRL parameter lists (no Python); `unsloth_train()`, `unsloth_export_gguf()`.
  - Depends on: G4, G5
- **[G9]** `R/infer.R`: `unsloth_stream()` resolves the device at runtime and calls `streamer.end()` in a Python `finally`; a minimal stub test (built in this goal) proves a generation exception is raised in R instead of hanging.
  - Depends on: G4
- **[G7]** `R/vision.R`: vision load, LoRA, `as_vision_dataset()` with resizing, `unsloth_train_vision()` with `max_length = NULL` and collator response masking.
  - Depends on: G6
- **[G8]** `R/grpo.R`: `GRPOConfig`/`GRPOTrainer`/`adam_beta1` typos fixed; `as_grpo_reward()` validates the name, turns a single number into a list, and optionally passes kwargs; the bridge is tested against minimal stubs built in this goal.
  - Depends on: G6
- **[G10]** `R/hub_ollama.R` + `R/backends.R`: GGUF export runs once; the Modelfile is always written (with or without an eos token); llama-cli commands are built correctly; `/health` polling is tested against a local fake HTTP server (503 then 200); processx shutdown; whitespace warning.
  - Depends on: G6
- **[G13]** Tier 2 smoke test passes on the local **AMD ROCm** GPUs: `unsloth_doctor()` reports ROCm; a small 4-bit model loads, fine-tunes with LoRA, streams, exports GGUF, serves via a ROCm/HIP build of llama-server, and answers through `ellmer::chat_openai_compatible()`.
  - Depends on: G3, G6, G9, G10, G11 (ROCm support confirmed upstream)
  - Note: The spec targets CUDA; the user approved retargeting to ROCm. If G11 finds that unsloth has no usable ROCm path, this goal moves to Blocked.
- **[G12]** Release hygiene: README and `@examples` use `ellmer::chat_openai_compatible()`; every export is fully documented; the final `roxygenise()`, `test_local()`, and rcmdcheck all report 0/0/0.
  - Depends on: G3–G10

## Independent Backlog

- (none yet)

## Deferred

- **[D1]** CUDA validation of the original Tier 2 workflow.
  - Trigger: access to an NVIDIA CUDA host.
- **[D2]** Install the ellmer and ollamar Suggests locally for end-to-end examples.
  - Trigger: start of G10/G13.

## Blocked / Pruned

- (none)
