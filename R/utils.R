# Python interop and GGUF helpers. All internal.

#' Python reserved keywords (`keyword.kwlist`, Python 3.12).
#' @noRd
.py_keywords <- c(
  "False", "None", "True", "and", "as", "assert", "async", "await", "break",
  "class", "continue", "def", "del", "elif", "else", "except", "finally",
  "for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal",
  "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"
)

#' Coerce whole-number R values to integers for Python; `NULL` passes through.
#' @noRd
as_py_int <- function(x, arg = rlang::caller_arg(x)) {
  if (is.null(x)) return(NULL)
  if (!is.numeric(x) || !all(is.finite(x)) || !all(x == round(x))) {
    cli::cli_abort("{.arg {arg}} must be a whole number (finite, no fractional part).")
  }
  if (any(abs(x) > .Machine$integer.max)) {
    cli::cli_abort("{.arg {arg}} must be within the integer range (+/-{(.Machine$integer.max)}).")
  }
  as.integer(x)
}

#' Abort unless `name` is a single valid, non-keyword Python identifier.
#' @noRd
validate_py_identifier <- function(name) {
  if (!is.character(name) || length(name) != 1L || is.na(name) ||
      !grepl("^[A-Za-z_][A-Za-z0-9_]*$", name) || name %in% .py_keywords) {
    cli::cli_abort("{.val {name}} is not a valid Python identifier.")
  }
  invisible(name)
}

#' Map a half-precision dtype name to a torch dtype, validating before
#' touching torch (Hazard H4).
#' @noRd
as_py_dtype <- function(x, arg = rlang::caller_arg(x)) {
  if (is.null(x)) return(NULL)
  allowed <- c("float16", "fp16", "bfloat16", "bf16")
  if (!is.character(x) || length(x) != 1L || is.na(x) || !(x %in% allowed)) {
    cli::cli_abort("{.arg {arg}} must be one of {.val {allowed}}, not {.val {x}}.")
  }
  if (x %in% c("float16", "fp16")) torch$float16 else torch$bfloat16
}

#' List the parameter names a Python callable accepts.
#' @noRd
py_callable_params <- function(fn) {
  params <- inspect$signature(fn)$parameters$keys()
  as.character(unlist(reticulate::py_to_r(reticulate::import_builtins()$list(params))))
}

#' Return a device as a string, converting a Python device object if needed.
#' @noRd
py_as_device_string <- function(x) {
  if (is.character(x)) return(x)
  reticulate::py_str(x)
}

#' Find a model's device from its `device` attribute or first parameter;
#' defaults to `"cpu"`.
#' @noRd
resolve_model_device <- function(model) {
  dev <- tryCatch(py_as_device_string(model$device), error = function(e) NULL)
  if (is.null(dev)) {
    dev <- tryCatch({
      first <- reticulate::iter_next(reticulate::as_iterator(model$parameters()))
      if (is.null(first)) NULL else py_as_device_string(first$device)
    }, error = function(e) NULL)
  }
  if (is.null(dev) || length(dev) != 1L || is.na(dev) || !nzchar(dev)) "cpu" else dev
}

#' Find the best exported GGUF file under `save_dir`; `NULL` when none exist.
#' @noRd
.find_exported_gguf <- function(save_dir, quantization_method) {
  files <- list.files(save_dir, pattern = "\\.gguf$", recursive = TRUE,
                      full.names = TRUE)
  if (length(files) == 0L) return(NULL)
  files <- sort(files)
  base <- basename(files)
  quant <- tolower(gsub("-", "_", quantization_method, fixed = TRUE))
  matches_quant <- grepl(quant, tolower(gsub("-", "_", base, fixed = TRUE)), fixed = TRUE)
  is_f16 <- grepl("f16", base, ignore.case = TRUE)
  rank <- ifelse(matches_quant, 1L, ifelse(is_f16, 3L, 2L))
  best <- files[order(rank)][1L]
  normalizePath(best, winslash = "/", mustWork = FALSE)
}

#' Run the Python GGUF export and return the exported file path.
#' @noRd
.export_gguf <- function(object, save_dir, quantization_method = "q4_k_m",
                         max_memory_usage = 0.75) {
  quant_arg <- if (length(quantization_method) > 1L) {
    as.list(quantization_method)
  } else {
    quantization_method
  }
  object$model$save_pretrained_gguf(
    save_directory = save_dir,
    tokenizer = object$tokenizer,
    quantization_method = quant_arg,
    maximum_memory_usage = max_memory_usage
  )
  path <- .find_exported_gguf(save_dir, quantization_method[[1L]])
  if (is.null(path)) {
    cli::cli_abort("No GGUF file was exported to {.file {save_dir}}.")
  }
  path
}
