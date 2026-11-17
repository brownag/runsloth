test_that("package load does not initialize Python", {
  package_path <- normalizePath(testthat::test_path("..", ".."))
  if (file.exists(file.path(package_path, "DESCRIPTION"))) {
    code <- paste(
      sprintf("pkgload::load_all(%s, quiet = TRUE)", shQuote(package_path)),
      "stopifnot(!reticulate::py_available(initialize = FALSE))",
      sep = ";"
    )
  } else {
    code <- paste(
      "library(runsloth)",
      "stopifnot(!reticulate::py_available(initialize = FALSE))",
      sep = ";"
    )
  }
  output <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("-e", shQuote(code)),
    stdout = TRUE,
    stderr = TRUE,
    env = paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep))
  )
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  expect_identical(status, 0L, info = paste(output, collapse = "\n"))
})

test_that("integer and identifier helpers enforce their boundaries", {
  expect_identical(as_py_int(NULL), NULL)
  expect_identical(as_py_int(3.8), 3L)
  expect_identical(validate_py_identifier("_reward2"), "_reward2")
  expect_error(validate_py_identifier("not-valid"), class = "rlang_error")
})

test_that("GGUF selection prefers the requested quantization", {
  dir <- tempfile()
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  file.create(file.path(dir, c("model-f16.gguf", "model-Q4_K_M.gguf")))
  expect_match(tolower(.find_exported_gguf(dir, "q4_k_m")), "q4_k_m")
})

test_that("doctor reports diagnostic categories safely without Python", {
  skip_if(reticulate::py_available(initialize = FALSE),
          "Python already available in this test process")
  report <- unsloth_doctor()
  expect_true(all(c("python_available", "torch_available", "cuda_available",
                    "bfloat16_supported", "versions", "tools") %in% names(report)))
  expect_false(report$python_available)
  expect_named(report$versions, c("unsloth", "unsloth_zoo", "trl", "transformers"))
  expect_named(report$tools, c("llama-server", "llama-cli", "ollama"))
})
