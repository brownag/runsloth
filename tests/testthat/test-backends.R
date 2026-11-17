test_that("llama.cpp command arguments are formatted for cli mode", {
  command <- launch_llamacpp(
    "model file.gguf", mode = "cli", bin = "/usr/bin/llama-cli",
    n_gpu_layers = 12L, ctx_size = 2048L, extra_args = "--verbose")
  expect_match(command, "--model")
  expect_match(command, shQuote("model file.gguf"), fixed = TRUE)
  expect_match(command, "-ngl")
  expect_match(command, "--jinja")
})

test_that("server health polling handles readiness and timeout", {
  local_mocked_bindings(.llamacpp_health_status = function(url) 200L)
  expect_true(.wait_llamacpp_healthy("http://localhost/health", timeout = 0))

  local_mocked_bindings(.llamacpp_health_status = function(url) 503L)
  expect_error(.wait_llamacpp_healthy(
    "http://localhost/health", timeout = 0), "did not become healthy")
})

test_that("Modelfile is written with or without EOS token", {
  dir <- tempfile()
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  gguf <- file.path(dir, "model-q4_k_m.gguf")
  file.create(gguf)
  path <- file.path(dir, "Modelfile")

  .write_ollama_modelfile(path, gguf, eos_token = "<eos>")
  expect_true(file.exists(path))
  expect_true(any(grepl('PARAMETER stop "<eos>"', readLines(path), fixed = TRUE)))

  .write_ollama_modelfile(path, gguf, eos_token = NULL)
  expect_true(file.exists(path))
  expect_false(any(grepl("PARAMETER stop", readLines(path), fixed = TRUE)))
})

test_that("Ollama dispatch reuses the single exported GGUF", {
  exports <- 0L
  local_mocked_bindings(
    .export_gguf_internal = function(object, save_dir, quantization_method,
                                     max_memory_usage = 0.75) {
      exports <<- exports + 1L
      dir.create(save_dir, recursive = TRUE, showWarnings = FALSE)
      path <- file.path(save_dir, "model-q4_k_m.gguf")
      file.create(path)
      path
    },
    .register_ollama_from_dir = function(object, save_dir, model_name,
                                         quantization_method, ollama = NULL) {
      expect_true(file.exists(file.path(save_dir, "model-q4_k_m.gguf")))
      model_name
    }
  )
  result <- unsloth_export_and_run(
    list(model = NULL, tokenizer = NULL), save_dir = tempfile(),
    backend = "ollama", model_name = "test-model")
  expect_identical(result, "test-model")
  expect_identical(exports, 1L)
})
