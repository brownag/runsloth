test_that("as_py_int coerces whole numbers and rejects the rest", {
  expect_null(as_py_int(NULL))
  expect_identical(as_py_int(2), 2L)
  expect_identical(as_py_int(c(1, 2)), c(1L, 2L))
  expect_identical(as_py_int(numeric(0)), integer(0))
  expect_error(as_py_int(2.5))
  expect_error(as_py_int(NA))
  expect_error(as_py_int(Inf))
  expect_error(as_py_int("a"))
  expect_error(as_py_int(TRUE))
})

test_that("validate_py_identifier accepts identifiers and rejects others", {
  expect_identical(validate_py_identifier("good_name1"), "good_name1")
  expect_invisible(validate_py_identifier("ok"))
  expect_error(validate_py_identifier("1abc"))
  expect_error(validate_py_identifier("a-b"))
  expect_error(validate_py_identifier("class"))
  expect_error(validate_py_identifier(c("a", "b")))
  expect_error(validate_py_identifier(NA_character_))
})

test_that("as_py_dtype returns NULL for NULL and rejects unknown dtypes", {
  expect_null(as_py_dtype(NULL))
  expect_error(as_py_dtype("float64"))
})

test_that(".find_exported_gguf ranks quantized, then other, then f16/bf16", {
  dir <- withr::local_tempdir()
  file.create(file.path(dir, "model-F16.gguf"))
  file.create(file.path(dir, "model-Q4_K_M.gguf"))
  expect_identical(
    basename(.find_exported_gguf(dir, "q4_k_m")),
    "model-Q4_K_M.gguf"
  )
  expect_identical(
    basename(.find_exported_gguf(dir, "q8_0")),
    "model-Q4_K_M.gguf"
  )
  expect_identical(
    basename(.find_exported_gguf(dir, "q4_k_m")),
    "model-Q4_K_M.gguf"
  )
})

test_that(".find_exported_gguf returns the f16 file when it is the only one", {
  dir <- withr::local_tempdir()
  file.create(file.path(dir, "model-F16.gguf"))
  expect_identical(basename(.find_exported_gguf(dir, "q4_k_m")), "model-F16.gguf")
})

test_that(".find_exported_gguf returns NULL for empty or missing dirs", {
  dir <- withr::local_tempdir()
  expect_null(.find_exported_gguf(dir, "q4_k_m"))
  expect_null(.find_exported_gguf(file.path(dir, "missing"), "q4_k_m"))
})

test_that(".find_exported_gguf searches nested subdirectories", {
  dir <- withr::local_tempdir()
  sub <- file.path(dir, "nested")
  dir.create(sub)
  file.create(file.path(sub, "model-Q4_K_M.gguf"))
  expect_identical(basename(.find_exported_gguf(dir, "q4_k_m")), "model-Q4_K_M.gguf")
})

test_that(".export_gguf_internal passes arguments by keyword and returns the path", {
  dir <- withr::local_tempdir()
  env <- new.env(parent = emptyenv())
  object <- list(
    model = list(
      save_pretrained_gguf = function(save_dir, tokenizer, quantization_method,
                                      maximum_memory_usage) {
        env$call <- sys.call()
        env$quant <- quantization_method
        env$tokenizer <- tokenizer
        file.create(file.path(save_dir, "m-Q8_0.gguf"))
      }
    ),
    tokenizer = "tok"
  )
  path <- .export_gguf_internal(object, dir, quantization_method = "q8_0")
  expect_identical(basename(path), "m-Q8_0.gguf")
  expect_identical(names(env$call)[-1], c("", "tokenizer", "quantization_method",
                                          "maximum_memory_usage"))
  expect_identical(env$tokenizer, "tok")
  expect_identical(env$quant, "q8_0")
})

test_that(".export_gguf_internal sends multiple quantization methods as a list", {
  dir <- withr::local_tempdir()
  env <- new.env(parent = emptyenv())
  object <- list(
    model = list(
      save_pretrained_gguf = function(save_dir, tokenizer, quantization_method,
                                      maximum_memory_usage) {
        env$quant <- quantization_method
        file.create(file.path(save_dir, "m-Q8_0.gguf"))
      }
    ),
    tokenizer = "tok"
  )
  path <- .export_gguf_internal(object, dir, quantization_method = c("q4_k_m", "q8_0"))
  expect_true(is.list(env$quant))
  expect_identical(unlist(env$quant), c("q4_k_m", "q8_0"))
  expect_identical(basename(path), "m-Q8_0.gguf")
})

test_that(".export_gguf_internal aborts when no GGUF is produced", {
  dir <- withr::local_tempdir()
  object <- list(
    model = list(save_pretrained_gguf = function(save_dir, tokenizer,
                                                 quantization_method,
                                                 maximum_memory_usage) NULL),
    tokenizer = "tok"
  )
  expect_error(.export_gguf_internal(object, dir))
})

test_that("py_callable_params lists parameter names", {
  skip_if_no_python()
  reticulate::py_run_string("def f(a, b=1, *args, c, **kw):\n    pass")
  fn <- reticulate::py_eval("f", convert = FALSE)
  expect_identical(py_callable_params(fn), c("a", "b", "args", "c", "kw"))
})

test_that("resolve_model_device reads device attribute or defaults to cpu", {
  skip_if_no_python()
  reticulate::py_run_string("class _M:\n    device = 'meta'\n")
  m <- reticulate::py_eval("_M()", convert = FALSE)
  expect_identical(resolve_model_device(m), "meta")
  bare <- reticulate::py_eval("object()", convert = FALSE)
  expect_identical(resolve_model_device(bare), "cpu")
})
