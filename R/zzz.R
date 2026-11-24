unsloth <- NULL
trl <- NULL
datasets <- NULL
transformers <- NULL
torch <- NULL
inspect <- NULL

# Forces the unsloth import. Used as the before_load hook for delayed modules,
# so unsloth is always imported before trl, transformers, or datasets.
#' @noRd
ensure_unsloth <- function() {
  invisible(unsloth$FastLanguageModel)
}

.onLoad <- function(libname, pkgname) {
  unsloth <<- reticulate::import("unsloth", delay_load = TRUE)
  torch <<- reticulate::import("torch", delay_load = TRUE)
  inspect <<- reticulate::import("inspect", delay_load = TRUE)

  hook <- list(before_load = function() ensure_unsloth())
  trl <<- reticulate::import("trl", delay_load = hook)
  transformers <<- reticulate::import("transformers", delay_load = hook)
  datasets <<- reticulate::import("datasets", delay_load = hook)

  if (isTRUE(getOption("runsloth.use_py_require", FALSE)) &&
      exists("py_require", envir = asNamespace("reticulate"))) {
    reticulate::py_require("unsloth")
  }
  invisible()
}
