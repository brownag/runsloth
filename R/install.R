#' Install Unsloth and its Python dependencies
#'
#' Installs dependencies into an explicitly selected virtualenv or conda
#' environment. Python package installation is never performed at package load.
#'
#' @param envname Environment name.
#' @param method Environment type: auto, virtualenv, or conda.
#' @param with_xformers Install optional xformers.
#' @param upgrade Use Unsloth's recovery upgrade options.
#' @return Invisibly returns the environment name.
#' @export
#' @examples
#' \dontrun{install_unsloth()}
install_unsloth <- function(envname = "r-unsloth",
                            method = c("auto", "virtualenv", "conda"),
                            with_xformers = FALSE, upgrade = FALSE) {
  method <- match.arg(method)
  packages <- c("unsloth", "unsloth_zoo", "trl", "peft", "accelerate",
                "bitsandbytes", "datasets")
  if (isTRUE(with_xformers)) packages <- c(packages, "xformers")
  if (isTRUE(upgrade)) {
    for (package in c("unsloth", "unsloth_zoo")) {
      reticulate::py_install(
        package, envname = envname, method = method, pip = TRUE,
        pip_options = c("--upgrade", "--force-reinstall", "--no-cache-dir", "--no-deps")
      )
    }
    packages <- setdiff(packages, c("unsloth", "unsloth_zoo"))
  }
  if (length(packages)) {
    reticulate::py_install(packages, envname = envname, method = method, pip = TRUE)
  }
  cli::cli_inform(c(
    "Python packages installed in {.val {envname}}.",
    "i" = if (method == "conda")
      "Activate with reticulate::use_condaenv()."
    else "Activate with reticulate::use_virtualenv().",
    "i" = if (upgrade)
      "If compiled artifacts remain stale, remove the unsloth_compiled_cache directory."
  ))
  invisible(envname)
}

#' Opt into reticulate-managed Python
#'
#' Requests an Unsloth environment using reticulate's optional `py_require()`
#' capability. This does not initialize Python.
#'
#' @param packages Python packages to request.
#' @param python_version Optional Python version.
#' @return Invisibly returns the result of `py_require()`.
#' @export
#' @examples
#' \dontrun{unsloth_use_managed_python()}
unsloth_use_managed_python <- function(
    packages = c("unsloth", "trl", "datasets", "transformers"),
    python_version = NULL) {
  ns <- asNamespace("reticulate")
  if (!exists("py_require", envir = ns, inherits = FALSE)) {
    cli::cli_abort("Upgrade reticulate to a version that provides `py_require()`.")
  }
  args <- list(packages = packages)
  if (!is.null(python_version)) args$python_version <- python_version
  invisible(do.call(get("py_require", envir = ns), args))
}

#' Diagnose Python and local inference dependencies
#'
#' Reports Python availability, selected torch/CUDA capabilities, Python
#' package versions, and local runtime executables. Missing dependencies are
#' represented as unavailable rather than treated as errors.
#'
#' @return A named list of diagnostic values.
#' @export
#' @examples
#' unsloth_doctor()
unsloth_doctor <- function() {
  available <- tryCatch(reticulate::py_available(initialize = FALSE),
                        error = function(e) FALSE)
  result <- list(
    python_available = isTRUE(available),
    torch_available = NA,
    cuda_available = NA,
    bfloat16_supported = NA,
    versions = stats::setNames(as.list(rep(NA_character_, 4L)),
                               c("unsloth", "unsloth_zoo", "trl", "transformers")),
    tools = stats::setNames(as.list(Sys.which(c("llama-server", "llama-cli", "ollama"))),
                            c("llama-server", "llama-cli", "ollama"))
  )
  if (isTRUE(available)) {
    result$python <- tryCatch(reticulate::py_config()$version_string,
                              error = function(e) NA_character_)
    result$torch_available <- tryCatch(reticulate::py_module_available("torch"),
                                       error = function(e) FALSE)
    if (isTRUE(result$torch_available)) {
      result$cuda_available <- tryCatch(isTRUE(torch$cuda$is_available()),
                                        error = function(e) FALSE)
      result$bfloat16_supported <- tryCatch(
        isTRUE(unsloth$is_bfloat16_supported()), error = function(e) NA
      )
    }
    for (package in names(result$versions)) {
      result$versions[[package]] <- tryCatch(
        as.character(reticulate::import(package, delay_load = FALSE)$`__version__`),
        error = function(e) NA_character_
      )
    }
  }
  class(result) <- c("runsloth_doctor", "list")
  result
}
