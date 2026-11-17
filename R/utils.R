as_py_int <- function(x) {
  if (is.null(x)) NULL else as.integer(x)
}

as_py_dtype <- function(dtype) {
  if (is.null(dtype)) return(NULL)
  key <- tolower(dtype)
  if (key %in% c("float16", "fp16")) return(torch$float16)
  if (key %in% c("bfloat16", "bf16")) return(torch$bfloat16)
  dtype
}

py_callable_params <- function(fn) {
  tryCatch(
    names(reticulate::py_to_r(inspect$signature(fn)$parameters)),
    error = function(e) character()
  )
}

validate_py_identifier <- function(name) {
  if (length(name) != 1L || is.na(name) ||
      !grepl("^[A-Za-z_][A-Za-z0-9_]*$", name)) {
    cli::cli_abort("`name` must be a valid Python identifier.")
  }
  name
}

resolve_model_device <- function(model) {
  tryCatch(as.character(reticulate::py_to_r(model$device)), error = function(e) "cpu")
}

.find_exported_gguf <- function(save_dir, quantization_method) {
  files <- list.files(save_dir, pattern = "\\.gguf$", full.names = TRUE, ignore.case = TRUE)
  if (!length(files)) return(NA_character_)
  wanted <- if (length(quantization_method)) as.character(quantization_method[[1L]]) else ""
  hits <- files[grepl(pattern = tolower(wanted), x = tolower(basename(files)), fixed = TRUE)]
  chosen <- if (length(hits)) hits else files
  chosen[[1L]]
}

.export_gguf_internal <- function(object, save_dir, quantization_method,
                                  max_memory_usage = 0.75) {
  methods <- as.list(quantization_method)
  object$model$save_pretrained_gguf(
    save_dir,
    tokenizer = object$tokenizer,
    quantization_method = methods,
    maximum_memory_usage = max_memory_usage
  )
  .find_exported_gguf(save_dir, quantization_method)
}
