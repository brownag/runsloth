test_that("generation options use greedy decoding without temperature", {
  expect_identical(
    .stream_generation_options(17, 0),
    list(max_new_tokens = 17L, do_sample = FALSE)
  )
  expect_identical(
    .stream_generation_options(17, 0.4),
    list(max_new_tokens = 17L, do_sample = TRUE, temperature = 0.4)
  )
})

test_that("chat prompts use the model chat-template contract", {
  formatted <- FALSE
  local_mocked_bindings(
    unsloth_apply_chat_template = function(object, dataset, ...) {
      formatted <<- TRUE
      "formatted prompt"
    }
  )
  result <- .stream_prompt(
    list(), list(list(role = "user", content = "hi")))
  expect_true(formatted)
  expect_identical(result, "formatted prompt")
})

test_that("generation worker always ends streamer and captures errors", {
  source <- readLines(testthat::test_path("../../R/infer.R"))
  worker <- paste(source, collapse = "\n")
  expect_match(worker, "finally:\\s*\\n\\s+runsloth_streamer\\.end\\(\\)")
  expect_match(worker, "runsloth_stream_error\\['message'\\] = str\\(exc\\)")
})

test_that("stream rejects images for language models before Python access", {
  object <- structure(list(model = NULL, tokenizer = NULL), class = "runsloth_model")
  expect_error(unsloth_stream(object, "hello", images = "image.png"),
               class = "rlang_error")
})
