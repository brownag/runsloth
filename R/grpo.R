#' Patch Unsloth for GRPO training
#'
#' Applies Unsloth's GRPO patches to its language-model implementation.
#'
#' @return Invisibly returns `NULL`.
#' @export
#' @examples
#' \dontrun{unsloth_patch_grpo()}
unsloth_patch_grpo <- function() {
  unsloth$PatchFastRL("GRPO", unsloth$FastLanguageModel)
  invisible(NULL)
}

#' Bridge an R reward callback to Python
#'
#' Creates a Python-callable reward function. When requested, Python keyword
#' arguments are passed to the R callback as named arguments. Scalar numeric
#' results are returned as one-element Python lists.
#'
#' @param r_fn An R function accepting `prompts` and `completions`.
#' @param name Valid Python identifier used to identify the reward callback.
#' @param pass_kwargs Whether to forward keyword arguments supplied by TRL.
#' @return A Python-callable reward function.
#' @export
#' @examples
#' \dontrun{
#' reward <- as_grpo_reward(function(prompts, completions) rep(1, length(completions)))
#' }
as_grpo_reward <- function(r_fn, name = "r_custom_reward", pass_kwargs = FALSE) {
  if (!is.function(r_fn)) cli::cli_abort("`r_fn` must be an R function.")
  validate_py_identifier(name)
  if (length(pass_kwargs) != 1L || is.na(pass_kwargs) || !is.logical(pass_kwargs)) {
    cli::cli_abort("`pass_kwargs` must be TRUE or FALSE.")
  }

  main <- reticulate::import_main(convert = FALSE)
  callback_name <- gsub(
    "[^A-Za-z0-9_]", "_",
    basename(tempfile(pattern = "runsloth_reward_callback_"))
  )
  main[[callback_name]] <- r_fn
  forward <- if (isTRUE(pass_kwargs)) {
    sprintf("%s(prompts, completions, **kwargs)", callback_name)
  } else {
    sprintf("%s(prompts, completions)", callback_name)
  }
  source <- sprintf(
    paste0(
      "def %s(prompts, completions, **kwargs):\n",
      "    result = %s\n",
      "    if isinstance(result, (int, float)):\n",
      "        return [float(result)]\n",
      "    return result"
    ),
    name, forward
  )
  reticulate::py_run_string(source, local = FALSE)
  main[[name]]
}

#' Train a language model with GRPO
#'
#' Builds a TRL `GRPOConfig` and `GRPOTrainer`, then runs training.
#'
#' @param object A `runsloth_model` returned by [unsloth_load_model()].
#' @param dataset A Hugging Face dataset or data frame accepted by
#'   [as_hf_dataset()].
#' @param reward_funcs One or more Python-callable reward functions.
#' @param output_dir Directory for trainer outputs.
#' @param learning_rate Learning rate.
#' @param per_device_train_batch_size Per-device training batch size.
#' @param gradient_accumulation_steps Number of accumulation steps.
#' @param num_generations Number of generations per prompt.
#' @param max_prompt_length Maximum prompt length.
#' @param max_completion_length Maximum completion length.
#' @param max_steps Maximum number of training steps.
#' @param logging_steps Logging interval.
#' @param warmup_steps Number of warmup steps.
#' @param seed Random seed.
#' @param adam_beta1 First Adam beta parameter.
#' @param ... Additional GRPOConfig keyword arguments.
#' @return Invisibly returns `object` after training.
#' @export
#' @examples
#' \dontrun{
#' unsloth_train_grpo(model, dataset, reward_funcs = list(reward))
#' }
unsloth_train_grpo <- function(
    object, dataset, reward_funcs, output_dir = "grpo_outputs",
    learning_rate = 5e-6, per_device_train_batch_size = 1L,
    gradient_accumulation_steps = 1L, num_generations = 4L,
    max_prompt_length = 512L, max_completion_length = 512L,
    max_steps = 100L, logging_steps = 1L, warmup_steps = 5L,
    seed = 3407L, adam_beta1 = 0.9, ...) {
  if (!is.list(reward_funcs)) reward_funcs <- list(reward_funcs)

  if (is.data.frame(dataset)) dataset <- as_hf_dataset(dataset)
  if (reticulate::py_has_attr(unsloth$FastLanguageModel, "for_training")) {
    unsloth$FastLanguageModel$for_training(object$model)
  }

  config_args <- c(list(
    output_dir = output_dir,
    learning_rate = learning_rate,
    per_device_train_batch_size = as_py_int(per_device_train_batch_size),
    gradient_accumulation_steps = as_py_int(gradient_accumulation_steps),
    num_generations = as_py_int(num_generations),
    max_prompt_length = as_py_int(max_prompt_length),
    max_completion_length = as_py_int(max_completion_length),
    max_steps = as_py_int(max_steps),
    logging_steps = as_py_int(logging_steps),
    warmup_steps = as_py_int(warmup_steps),
    seed = as_py_int(seed),
    adam_beta1 = adam_beta1
  ), list(...))
  config <- do.call(trl$GRPOConfig, config_args)

  trainer_params <- py_callable_params(trl$GRPOTrainer)
  tokenizer_arg <- if ("processing_class" %in% trainer_params) {
    "processing_class"
  } else {
    "tokenizer"
  }
  trainer_args <- list(
    model = object$model,
    args = config,
    train_dataset = dataset,
    reward_funcs = reward_funcs
  )
  trainer_args[[tokenizer_arg]] <- object$tokenizer
  trainer <- do.call(trl$GRPOTrainer, trainer_args)
  trainer$train()
  invisible(object)
}
