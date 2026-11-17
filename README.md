# runsloth

`runsloth` is an R interface to [Unsloth](https://unsloth.ai/), exposed through
[`reticulate`](https://rstudio.github.io/reticulate/). It provides R functions
for loading language and vision models, preparing chat data, supervised and
GRPO training, streaming inference, and exporting or publishing models.

**Loading the R package does not install or initialize Python.** Python
environment setup is explicit, so you can inspect the package and run its
offline R helpers without starting Python.

## Installation

Install R package dependencies from CRAN, then install this package from a
local checkout:

```r
install.packages(c("reticulate", "cli"))
```

```sh
R CMD INSTALL .
```

Once the package is installed, create an environment and install Unsloth's
Python dependencies:

```r
library(runsloth)

install_unsloth(envname = "r-unsloth", method = "virtualenv")
```

Before the first Python-backed call in each R session, select that environment:

```r
reticulate::use_virtualenv("r-unsloth", required = TRUE)
```

Choose a compatible Python and PyTorch/CUDA setup for your platform before
training. `install_unsloth()` installs Python packages; it does not guarantee
that your machine has a supported GPU or CUDA runtime. See
`?install_unsloth` and `?unsloth_doctor` for setup and diagnostics.

## Quick start: language-model SFT

After configuring reticulate, load a model, attach LoRA adapters, format
conversation data with its chat template, and train:

```r
library(runsloth)

model <- unsloth_load_model(
  "unsloth/Llama-3.2-3B-Instruct-bnb-4bit",
  max_seq_length = 2048L,
  load_in_4bit = TRUE
)
model <- unsloth_add_lora(model)
model <- unsloth_set_chat_template(model, "chatml")

conversations <- list(
  list(
    list(role = "user", content = "What is 6 multiplied by 7?"),
    list(role = "assistant", content = "6 multiplied by 7 is 42.")
  )
)
dataset <- unsloth_apply_chat_template(model, conversations)
unsloth_train(model, dataset, max_seq_length = 2048L)
```

Training and model loading may download model/data files and generally require
substantial memory; 4-bit loading does not make every model fit every device.
Use `unsloth_build_trainer()` when you want to configure a trainer without
starting training. Pass an R data frame with a `text` column or a Hugging Face
dataset to the SFT functions.

## Other workflows

### Vision fine-tuning

Use `unsloth_load_vision_model()`, `unsloth_add_vision_lora()`,
`as_vision_dataset()`, and `unsloth_train_vision()` for image-and-text
workflows. `as_vision_dataset()` opens images through Python's Pillow package;
provide local image paths and install the required Python dependencies first.

### GRPO and reward functions

`as_grpo_reward()` wraps an R callback as a Python-callable reward function.
The callback should return one score per completion. For example, replace this
placeholder reward with an application-specific scoring function:

```r
reward <- as_grpo_reward(function(prompts, completions) {
  rep(1, length(completions))
})
```

Use `unsloth_train_grpo()` with a model, dataset, and `reward_funcs = list(reward)`.
GRPO requires compatible Python training dependencies and suitable compute.

### Streaming inference

`unsloth_stream()` accepts a text prompt or chat turns and sends generated
chunks to a callback (printing is the default):

```r
answer <- unsloth_stream(
  model,
  "Explain why the sky appears blue.",
  callback = function(chunk) cat(chunk)
)
```

The returned value is the complete generated text, invisibly. Vision models
can also receive image input; see `?unsloth_stream` for its accepted form.

### Hub and local backends

- `unsloth_push_to_hub()` supports LoRA, merged, and GGUF publishing. Set
  `HF_TOKEN` or pass a token explicitly; this performs a network upload.
- `unsloth_export_gguf()` exports a model locally.
- `unsloth_export_and_run()` can export and dispatch to llama.cpp, Ollama, or
  return the GGUF path without launching a backend.
- `launch_llamacpp()` starts a server or formats a CLI command.
  `unsloth_stop_server()` stops servers for which a managed process handle is
  available. When `processx` is unavailable, the `system2()` fallback cannot
  be stopped through the returned object; stop that process externally.

These operations may use substantial disk space, download files, upload model
artifacts, or start local services. They are not part of the offline test suite.

## Diagnostics and help

```r
unsloth_doctor()
```

The diagnostic report does not initialize Python when Python is not already
available. Function reference pages are available with `?function_name`, for
example `?unsloth_load_model`, `?unsloth_train`, and `?unsloth_export_and_run`.

## Development

From the repository root:

```sh
make help
make document
make test
make check
```

The check target disables force-installation of optional Suggests, which may
not be installed in every development environment. GPU, live Hub, and
live-server integration checks require separate setup.

## License

Apache License 2.0. See the package `LICENSE` file.
