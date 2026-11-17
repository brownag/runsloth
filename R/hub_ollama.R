#' Push a model to the Hugging Face Hub
#'
#' @param object A `runsloth_model`.
#' @param repo_id Hugging Face repository identifier.
#' @param mode One of `"lora"`, `"merged_16bit"`, `"merged_4bit"`, or `"gguf"`.
#' @param token Optional Hub token; defaults to `HF_TOKEN`.
#' @param save_dir Directory used for GGUF export.
#' @param quantization_method GGUF quantization method or methods.
#' @param max_memory_usage Maximum memory fraction for GGUF export.
#' @param ... Additional arguments passed to the relevant Unsloth Hub method.
#' @return Invisibly returns the Hub upload result.
#' @export
#' @examples
#' \dontrun{unsloth_push_to_hub(object, "user/model")}
unsloth_push_to_hub <- function(
    object, repo_id, mode = c("lora", "merged_16bit", "merged_4bit", "gguf"),
    token = Sys.getenv("HF_TOKEN", unset = ""), save_dir = "model_gguf",
    quantization_method = "q4_k_m", max_memory_usage = 0.75, ...) {
  mode <- match.arg(mode)
  if (!nzchar(token)) cli::cli_abort("Provide `token` or set the `HF_TOKEN` environment variable.")
  model <- object$model
  tokenizer <- object$tokenizer

  if (mode == "gguf") {
    result <- model$push_to_hub_gguf(
      repo_id, tokenizer = tokenizer, quantization_method = as.list(quantization_method),
      token = token, maximum_memory_usage = max_memory_usage, ...)
    return(invisible(result))
  }

  if (mode == "lora") {
    result <- model$push_to_hub(repo_id, token = token, ...)
    tokenizer$push_to_hub(repo_id, token = token)
  } else {
    merge_method <- if (mode == "merged_16bit") "merged_16bit" else "merged_4bit"
    result <- model$push_to_hub_merged(
      repo_id, tokenizer = tokenizer, save_method = merge_method,
      token = token, ...)
  }
  invisible(result)
}

.write_ollama_modelfile <- function(path, gguf_path, eos_token = NULL,
                                    template = NULL) {
  lines <- c(paste("FROM", normalizePath(gguf_path, mustWork = FALSE)))
  if (!is.null(eos_token) && length(eos_token) == 1L && nzchar(eos_token)) {
    lines <- c(lines, paste0('PARAMETER stop "', eos_token, '"'))
  }
  if (!is.null(template) && length(template) == 1L && nzchar(template)) {
    lines <- c(lines, paste0('TEMPLATE """', template, '"""'))
  }
  writeLines(lines, path)
  invisible(path)
}

.register_ollama_from_dir <- function(object, save_dir, model_name,
                                      quantization_method = "q4_k_m",
                                      ollama = NULL) {
  gguf_path <- .find_exported_gguf(save_dir, quantization_method)
  if (is.na(gguf_path)) cli::cli_abort("No GGUF model was found in `{save_dir}`.")
  modelfile <- file.path(save_dir, "Modelfile")
  eos_token <- tryCatch(
    as.character(reticulate::py_to_r(object$tokenizer$eos_token)),
    error = function(e) NULL)
  .write_ollama_modelfile(modelfile, gguf_path, eos_token)
  if (is.null(ollama)) {
    if (!requireNamespace("ollamar", quietly = TRUE)) {
      cli::cli_abort("Install the optional `ollamar` package to register an Ollama model.")
    }
    ollama <- getExportedValue("ollamar", "create")
  }
  ollama(model = model_name, modelfile = modelfile)
  invisible(model_name)
}

#' Register a GGUF model with Ollama
#'
#' @param object A `runsloth_model`.
#' @param model_name Name to assign to the Ollama model.
#' @param gguf_path Existing GGUF path, or `NULL` to export one.
#' @param save_dir Directory used for GGUF export and Modelfile.
#' @param quantization_method GGUF quantization method.
#' @param max_memory_usage Maximum memory fraction for GGUF export.
#' @return The model name, invisibly.
#' @export
#' @examples
#' \dontrun{unsloth_register_ollama(object, "local-model")}
unsloth_register_ollama <- function(
    object, model_name, gguf_path = NULL, save_dir = "model_gguf",
    quantization_method = "q4_k_m", max_memory_usage = 0.75) {
  if (is.null(gguf_path)) {
    gguf_path <- .export_gguf_internal(
      object, save_dir, quantization_method, max_memory_usage)
  }
  dir.create(save_dir, recursive = TRUE, showWarnings = FALSE)
  modelfile <- file.path(save_dir, "Modelfile")
  eos_token <- tryCatch(
    as.character(reticulate::py_to_r(object$tokenizer$eos_token)),
    error = function(e) NULL)
  .write_ollama_modelfile(modelfile, gguf_path, eos_token)
  if (!requireNamespace("ollamar", quietly = TRUE)) {
    cli::cli_abort("Install the optional `ollamar` package to register an Ollama model.")
  }
  getExportedValue("ollamar", "create")(model = model_name, modelfile = modelfile)
  invisible(model_name)
}
