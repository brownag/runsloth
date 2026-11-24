.runsloth_test_env <- new.env(parent = emptyenv())

# Resolves an explicit Python interpreter (never lets reticulate provision one)
# and caches either the path or a skip reason for the whole test run.
skip_if_no_python <- function() {
  testthat::skip_on_cran()
  if (!exists("python", envir = .runsloth_test_env, inherits = FALSE)) {
    path <- Sys.getenv("RUNSLOTH_TEST_PYTHON", unset = "")
    if (!nzchar(path)) path <- unname(Sys.which("python3"))
    if (!nzchar(path)) {
      assign("python", list(skip = "No Python interpreter found for tests"),
             envir = .runsloth_test_env)
    } else {
      ok <- tryCatch({
        reticulate::use_python(path, required = TRUE)
        TRUE
      }, error = function(e) conditionMessage(e))
      if (isTRUE(ok)) {
        assign("python", list(path = path), envir = .runsloth_test_env)
      } else {
        assign("python", list(skip = paste("Cannot use Python:", ok)),
               envir = .runsloth_test_env)
      }
    }
  }
  state <- get("python", envir = .runsloth_test_env, inherits = FALSE)
  if (!is.null(state$skip)) testthat::skip(state$skip)
  invisible(state$path)
}

skip_if_no_unsloth <- function() {
  skip_if_no_python()
  if (!reticulate::py_module_available("unsloth")) {
    testthat::skip("Python module 'unsloth' not available")
  }
  invisible()
}

skip_if_no_gpu <- function() {
  skip_if_no_unsloth()
  torch <- reticulate::import("torch")
  if (!isTRUE(reticulate::py_to_r(torch$cuda$is_available()))) {
    testthat::skip("No GPU available (CUDA or ROCm torch build)")
  }
  invisible()
}
