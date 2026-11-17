.llamacpp_cli_args <- function(gguf_path, n_gpu_layers, ctx_size, extra_args) {
  c("--model", gguf_path, "-ngl", as.character(n_gpu_layers),
    "-c", as.character(ctx_size), "--jinja", extra_args)
}

.llamacpp_server_args <- function(gguf_path, host, port, n_gpu_layers,
                                  ctx_size, extra_args) {
  c("--model", gguf_path, "--host", host, "--port", as.character(port),
    "--n-gpu-layers", as.character(n_gpu_layers), "--ctx-size",
    as.character(ctx_size), "--jinja", extra_args)
}

.llamacpp_health_status <- function(url) {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    cli::cli_abort("Install the optional `httr2` package for server health checks.")
  }
  tryCatch(httr2::request(url) |>
             httr2::req_timeout(2) |>
             httr2::req_perform() |>
             httr2::resp_status(),
           error = function(e) NA_integer_)
}

.wait_llamacpp_healthy <- function(url, timeout) {
  started <- Sys.time()
  repeat {
    if (identical(.llamacpp_health_status(url), 200L)) return(invisible(TRUE))
    if (as.numeric(difftime(Sys.time(), started, units = "secs")) >= timeout) {
      cli::cli_abort("llama-server did not become healthy at `{url}` within {timeout} seconds.")
    }
    Sys.sleep(0.25)
  }
}

#' Export a model and run a local inference backend
#'
#' @param object A `runsloth_model`.
#' @param save_dir GGUF output directory.
#' @param backend Backend: `llamacpp`, `ollama`, or `none`.
#' @param mode llama.cpp mode: `server` or `cli`.
#' @param model_name Optional Ollama model name.
#' @param quantization_method GGUF quantization method.
#' @param max_memory_usage Maximum memory fraction for export.
#' @param bin llama.cpp executable path.
#' @param host Server bind address.
#' @param port Server port.
#' @param n_gpu_layers Number of layers to offload.
#' @param ctx_size Context size.
#' @param timeout Server health timeout in seconds.
#' @param extra_args Additional backend command-line arguments.
#' @return GGUF path, CLI command, server object, or Ollama model name.
#' @export
#' @examples
#' \dontrun{srv <- unsloth_export_and_run(object)}
#' \dontrun{ellmer::chat_openai_compatible(base_url = srv$base_url, model = "local-gguf")}
unsloth_export_and_run <- function(
    object, save_dir = "model_gguf", backend = c("llamacpp", "ollama", "none"),
    mode = c("server", "cli"), model_name = NULL,
    quantization_method = "q4_k_m", max_memory_usage = 0.75,
    bin = NULL, host = "127.0.0.1", port = 8080L, n_gpu_layers = 0L,
    ctx_size = 4096L, timeout = 60, extra_args = character()) {
  backend <- match.arg(backend)
  mode <- match.arg(mode)
  if (grepl("[[:space:]]", save_dir)) {
    cli::cli_warn("`save_dir` contains whitespace; external backend commands may not handle it.")
  }
  gguf_path <- .export_gguf_internal(
    object, save_dir, quantization_method, max_memory_usage)
  if (backend == "none") return(invisible(gguf_path))
  if (backend == "ollama") {
    if (is.null(model_name)) model_name <- basename(save_dir)
    return(invisible(.register_ollama_from_dir(
      object, save_dir, model_name, quantization_method)))
  }
  launch_llamacpp(
    gguf_path, mode = mode, bin = bin, host = host, port = port,
    n_gpu_layers = n_gpu_layers, ctx_size = ctx_size, timeout = timeout,
    extra_args = extra_args)
}

#' Launch llama.cpp CLI or server
#'
#' @param gguf_path GGUF model path.
#' @param mode `server` or `cli`.
#' @param bin Executable path; inferred from mode when `NULL`.
#' @param host Server bind address.
#' @param port Server port.
#' @param n_gpu_layers Number of layers to offload.
#' @param ctx_size Context size.
#' @param timeout Health-check timeout in seconds.
#' @param extra_args Additional command-line arguments.
#' @return A CLI command string or `runsloth_server` object.
#' @export
#' @examples
#' \dontrun{srv <- launch_llamacpp("model.gguf")}
launch_llamacpp <- function(
    gguf_path, mode = c("server", "cli"), bin = NULL, host = "127.0.0.1",
    port = 8080L, n_gpu_layers = 0L, ctx_size = 4096L, timeout = 60,
    extra_args = character()) {
  mode <- match.arg(mode)
  if (is.null(bin)) {
    bin <- Sys.which(if (mode == "server") "llama-server" else "llama-cli")
  }
  if (!nzchar(bin)) cli::cli_abort("Could not find the llama.cpp executable for `{mode}` mode.")
  if (mode == "cli") {
    args <- .llamacpp_cli_args(gguf_path, n_gpu_layers, ctx_size, extra_args)
    return(paste(c(shQuote(bin), vapply(args, shQuote, character(1))), collapse = " "))
  }

  args <- .llamacpp_server_args(
    gguf_path, host, port, n_gpu_layers, ctx_size, extra_args)
  process <- NULL
  if (requireNamespace("processx", quietly = TRUE)) {
    process <- processx::process$new(
      bin, args = args, stdout = "|", stderr = "|", cleanup = TRUE)
  } else {
    warning("`processx` is unavailable; system2(wait = FALSE) cannot be stopped by unsloth_stop_server().",
            call. = FALSE)
    system2(bin, args = vapply(args, shQuote, character(1)), wait = FALSE)
  }
  base_url <- sprintf("http://%s:%s", host, as.integer(port))
  tryCatch(
    .wait_llamacpp_healthy(paste0(base_url, "/health"), timeout),
    error = function(error) {
      if (!is.null(process) && process$is_alive()) {
        process$kill()
        process$wait()
      }
      stop(error)
    }
  )
  structure(list(
    backend = "llamacpp", base_url = base_url,
    gguf_path = gguf_path, host = host, port = as.integer(port),
    process = process), class = "runsloth_server")
}

#' Stop a llama.cpp server
#'
#' @param server A `runsloth_server` returned by [launch_llamacpp()].
#' @return The server object, invisibly.
#' @export
#' @examples
#' \dontrun{unsloth_stop_server(srv)}
unsloth_stop_server <- function(server) {
  if (!inherits(server, "runsloth_server")) {
    cli::cli_abort("`server` must be a `runsloth_server` object.")
  }
  if (!is.null(server$process) && server$process$is_alive()) {
    server$process$kill()
    server$process$wait()
  }
  invisible(server)
}
