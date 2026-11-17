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
  received <- NULL
  tokenizer <- list(apply_chat_template = function(messages, ...) {
    received <<- list(messages = messages, ...)
    "formatted prompt with assistant prefix"
  })
  result <- .stream_prompt(
    list(tokenizer = tokenizer), list(list(role = "user", content = "hi")))
  expect_identical(result, "formatted prompt with assistant prefix")
  expect_identical(received$messages[[1]]$content, "hi")
  expect_identical(received$tokenize, FALSE)
  expect_identical(received$add_generation_prompt, TRUE)
})

test_that("stream worker is joined even when callback errors", {
  joined <- FALSE
  worker <- list(join = function() joined <<- TRUE)
  local_mocked_bindings(
    .stream_chunks = function(streamer) c("first", "second")
  )
  expect_error(
    .consume_stream(NULL, worker, function(chunk) {
      if (identical(chunk, "first")) stop("callback failed")
    }),
    "callback failed"
  )
  expect_true(joined)
})

test_that("stream consumption concatenates chunks and joins worker", {
  joined <- FALSE
  seen <- character()
  worker <- list(join = function() joined <<- TRUE)
  local_mocked_bindings(
    .stream_chunks = function(streamer) c("hello", " world")
  )
  result <- .consume_stream(NULL, worker, function(chunk) {
    seen <<- c(seen, chunk)
  })
  expect_identical(result, c("hello", " world"))
  expect_identical(seen, result)
  expect_true(joined)
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
