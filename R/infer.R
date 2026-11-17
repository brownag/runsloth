.stream_generation_options <- function(max_new_tokens, temperature) {
  args <- list(
    max_new_tokens = as_py_int(max_new_tokens),
    do_sample = isTRUE(temperature > 0)
  )
  if (isTRUE(temperature > 0)) args$temperature <- temperature
  args
}

.stream_prompt <- function(object, prompt) {
  if (is.list(prompt)) {
    return(object$tokenizer$apply_chat_template(
      prompt, tokenize = FALSE, add_generation_prompt = TRUE))
  }
  prompt
}

.stream_chunks <- function(streamer) reticulate::iterate(streamer)

.consume_stream <- function(streamer, worker, callback) {
  on.exit(worker$join(), add = TRUE)
  chunks <- character()
  for (chunk in .stream_chunks(streamer)) {
    chunk <- as.character(chunk)
    chunks <- c(chunks, chunk)
    callback(chunk)
  }
  chunks
}

#' Stream generated text from an Unsloth model
#'
#' Streams generated tokens to `callback` while generation runs in a Python
#' background thread. Chat prompts are formatted with the model's chat template.
#'
#' @param object A `runsloth_model` or `runsloth_vision_model`.
#' @param prompt Text or a list of chat turns.
#' @param images Optional image input for a vision model.
#' @param max_new_tokens Maximum number of tokens to generate.
#' @param temperature Sampling temperature; non-positive values use greedy decoding.
#' @param callback Function called with each decoded text chunk.
#' @return The concatenated generated text, invisibly.
#' @export
#' @examples
#' \dontrun{unsloth_stream(model, "Explain photosynthesis.")}
unsloth_stream <- function(
    object, prompt, images = NULL, max_new_tokens = 512L, temperature = 0.7,
    callback = function(chunk) {
      cat(chunk)
      utils::flush.console()
    }) {
  if (!inherits(object, "runsloth_model")) {
    cli::cli_abort("`object` must be a runsloth model.")
  }
  vision <- inherits(object, "runsloth_vision_model") || isTRUE(object$is_vision)
  if (!is.null(images) && !vision) {
    cli::cli_abort("`images` can only be used with a vision model.")
  }

  inference <- if (vision) unsloth$FastVisionModel else unsloth$FastLanguageModel
  inference$for_inference(object$model)
  prompt <- .stream_prompt(object, prompt)
  prompt <- as.character(prompt)
  inputs <- if (is.null(images)) {
    object$tokenizer(prompt, return_tensors = "pt")
  } else {
    object$tokenizer(text = prompt, images = images, return_tensors = "pt")
  }
  device <- resolve_model_device(object$model)
  inputs <- inputs$to(device)
  streamer <- transformers$TextIteratorStreamer(
    object$tokenizer, skip_prompt = TRUE)
  kwargs <- .stream_generation_options(max_new_tokens, temperature)

  main <- reticulate::import_main()
  main$runsloth_stream_model <- object$model
  main$runsloth_stream_inputs <- inputs
  main$runsloth_stream_kwargs <- reticulate::r_to_py(kwargs, convert = FALSE)
  main$runsloth_streamer <- streamer
  reticulate::py_run_string("
def _runsloth_stream_generate():
    try:
        runsloth_stream_model.generate(**dict(runsloth_stream_inputs, **runsloth_stream_kwargs,
                                              streamer=runsloth_streamer))
    except Exception as exc:
        runsloth_stream_error['message'] = str(exc)
    finally:
        runsloth_streamer.end()
runsloth_stream_error = {}
", local = FALSE)
  worker <- reticulate::import("threading", delay_load = FALSE)$Thread(
    target = main$`_runsloth_stream_generate`)
  worker$start()
  chunks <- .consume_stream(streamer, worker, callback)
  error <- reticulate::py_to_r(main$runsloth_stream_error)
  if (length(error$message)) cli::cli_abort("Generation failed: {error$message}")
  result <- paste0(chunks, collapse = "")
  cat("\n")
  invisible(result)
}
