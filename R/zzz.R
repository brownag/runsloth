unsloth <- trl <- datasets <- transformers <- torch <- inspect <- NULL

ensure_unsloth <- function() {
  force(unsloth$FastLanguageModel)
  invisible(NULL)
}

.onLoad <- function(libname, pkgname) {
  ns <- asNamespace("reticulate")
  package_ns <- parent.env(environment())
  import <- get("import", envir = ns)
  assign("unsloth", import("unsloth", delay_load = TRUE), envir = package_ns)
  assign("trl", import("trl", delay_load = list(before_load = ensure_unsloth)), envir = package_ns)
  assign("transformers", import("transformers", delay_load = list(before_load = ensure_unsloth)), envir = package_ns)
  assign("datasets", import("datasets", delay_load = list(before_load = ensure_unsloth)), envir = package_ns)
  assign("torch", import("torch", delay_load = TRUE), envir = package_ns)
  assign("inspect", import("inspect", delay_load = TRUE), envir = package_ns)
  if (isTRUE(getOption("runsloth.use_py_require", FALSE)) &&
      exists("py_require", envir = ns, inherits = FALSE)) {
    get("py_require", envir = ns)("unsloth")
  }
}
