#' Convert an R data frame to a Hugging Face Dataset
#'
#' @param df Data frame to convert.
#' @return A Python Hugging Face Dataset.
#' @export
#' @examples
#' \dontrun{dataset <- as_hf_dataset(data.frame(text = "hello"))}
as_hf_dataset <- function(df) {
  if (!is.data.frame(df)) cli::cli_abort("`df` must be a data frame.")
  columns <- lapply(as.list(df), function(column) {
    if (is.list(column)) column else as.list(column)
  })
  datasets$Dataset$from_dict(columns)
}

.make_sft_config <- function(params, max_seq_length, dataset_text_field,
                             packing, dataset_num_proc, config_args) {
  config <- config_args
  if ("max_length" %in% params) config$max_length <- as_py_int(max_seq_length)
  else if ("max_seq_length" %in% params) {
    config$max_seq_length <- as_py_int(max_seq_length)
  }
  if ("dataset_text_field" %in% params) {
    config$dataset_text_field <- dataset_text_field
  }
  if ("packing" %in% params) config$packing <- packing
  if ("dataset_num_proc" %in% params) {
    config$dataset_num_proc <- as_py_int(dataset_num_proc)
  }
  config
}

#' Build an SFT trainer without starting training
#'
#' @param object A `runsloth_model`.
#' @param dataset Hugging Face Dataset or R data frame.
#' @param max_seq_length Maximum sequence length.
#' @param dataset_text_field Text column name.
#' @param packing Whether to pack examples.
#' @param dataset_num_proc Number of dataset processing processes.
#' @param train_on_responses_only Whether to mask non-response tokens.
#' @param instruction_part Optional instruction delimiter.
#' @param response_part Optional response delimiter.
#' @param ... Additional SFT config arguments.
#' @return An untrained SFT trainer.
#' @export
#' @examples
#' \dontrun{trainer <- unsloth_build_trainer(object, dataset)}
unsloth_build_trainer <- function(
    object, dataset, max_seq_length = object$max_seq_length,
    dataset_text_field = "text", packing = FALSE, dataset_num_proc = 1L,
    train_on_responses_only = FALSE, instruction_part = NULL,
    response_part = NULL, ...) {
  if (is.data.frame(dataset)) dataset <- as_hf_dataset(dataset)
  config_fn <- if (!is.null(trl$SFTConfig)) trl$SFTConfig else
    transformers$TrainingArguments
  config_params <- py_callable_params(config_fn)
  trainer_params <- py_callable_params(trl$SFTTrainer)
  config_args <- .make_sft_config(
    config_params, max_seq_length, dataset_text_field,
    packing, dataset_num_proc, list(...))
  config <- do.call(config_fn, config_args)
  args <- list(model = object$model, args = config, train_dataset = dataset)
  if ("processing_class" %in% trainer_params) {
    args$processing_class <- object$tokenizer
  } else if ("tokenizer" %in% trainer_params) {
    args$tokenizer <- object$tokenizer
  }
  if (!"dataset_text_field" %in% config_params &&
      "dataset_text_field" %in% trainer_params) {
    args$dataset_text_field <- dataset_text_field
  }
  if (!"max_length" %in% config_params &&
      !"max_seq_length" %in% config_params &&
      "max_seq_length" %in% trainer_params) {
    args$max_seq_length <- as_py_int(max_seq_length)
  }
  if (!"packing" %in% config_params && "packing" %in% trainer_params) {
    args$packing <- packing
  }
  if (!"dataset_num_proc" %in% config_params &&
      "dataset_num_proc" %in% trainer_params) {
    args$dataset_num_proc <- as_py_int(dataset_num_proc)
  }
  trainer <- do.call(trl$SFTTrainer, args)
  if (isTRUE(train_on_responses_only)) {
    trainer <- unsloth_train_on_responses_only(
      trainer, instruction_part, response_part)
  }
  trainer
}

#' Train a language model with supervised fine-tuning
#'
#' @param object A `runsloth_model`.
#' @param dataset Hugging Face Dataset or R data frame.
#' @param max_seq_length Maximum sequence length.
#' @param dataset_text_field Text column name.
#' @param packing Whether to pack examples.
#' @param dataset_num_proc Number of dataset processing processes.
#' @param train_on_responses_only Whether to mask non-response tokens first.
#' @param instruction_part Optional instruction delimiter.
#' @param response_part Optional response delimiter.
#' @param ... Additional SFT config arguments.
#' @return The model object, invisibly.
#' @export
#' @examples
#' \dontrun{object <- unsloth_train(object, dataset)}
unsloth_train <- function(
    object, dataset, max_seq_length = object$max_seq_length,
    dataset_text_field = "text", packing = FALSE, dataset_num_proc = 1L,
    train_on_responses_only = FALSE, instruction_part = NULL,
    response_part = NULL, ...) {
  if (!is.null(unsloth$FastLanguageModel$for_training)) {
    unsloth$FastLanguageModel$for_training(object$model)
  }
  trainer <- unsloth_build_trainer(
    object, dataset, max_seq_length, dataset_text_field, packing,
    dataset_num_proc, train_on_responses_only, instruction_part,
    response_part, ...)
  trainer$train()
  invisible(object)
}

#' Export a language model to GGUF
#'
#' @param object A `runsloth_model`.
#' @param save_dir Output directory.
#' @param quantization_method Quantization method or methods.
#' @param max_memory_usage Maximum memory fraction for export.
#' @return Exported GGUF path, invisibly.
#' @export
#' @examples
#' \dontrun{path <- unsloth_export_gguf(object)}
unsloth_export_gguf <- function(
    object, save_dir = "model_gguf", quantization_method = "q4_k_m",
    max_memory_usage = 0.75) {
  invisible(.export_gguf_internal(
    object, save_dir, quantization_method, max_memory_usage))
}
