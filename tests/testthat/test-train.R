test_that("HF conversion preserves atomic singleton columns as lists", {
  captured <- NULL
  local_mocked_bindings(datasets = list(Dataset = list(from_dict = function(x) {
    captured <<- x
    x
  })))
  result <- as_hf_dataset(data.frame(text = "only"))
  expect_identical(captured$text, list("only"))
  expect_identical(result, captured)
})

test_that("SFT config routes supported version-specific fields", {
  fields <- .make_sft_config(
    c("max_length", "dataset_text_field", "packing", "dataset_num_proc"),
    512, "content", TRUE, 2, list(seed = 7L))
  expect_identical(fields, list(
    seed = 7L, max_length = 512L, dataset_text_field = "content",
    packing = TRUE, dataset_num_proc = 2L
  ))
  legacy <- .make_sft_config(c("max_seq_length"), 128, "text", FALSE, 1L, list())
  expect_identical(legacy, list(max_seq_length = 128L))
})

test_that("trainer masking happens at construction before training", {
  events <- character()
  mock_unsloth <- list(
    FastLanguageModel = list(for_training = function(model) {
      events <<- c(events, "training_mode")
    }),
    trainer = list(train_on_responses_only = function(trainer, ...) {
      events <<- c(events, "mask")
      trainer
    })
  )
  mock_trl <- list(
    SFTConfig = function(...) list(...),
    SFTTrainer = function(...) {
      events <<- c(events, "build")
      list(train = function() events <<- c(events, "train"))
    }
  )
  local_mocked_bindings(
    unsloth = mock_unsloth, trl = mock_trl,
    datasets = list(Dataset = list(from_dict = function(x) x)),
    py_callable_params = function(fn) {
      if (identical(fn, mock_trl$SFTConfig)) {
        c("max_length", "dataset_text_field", "packing", "dataset_num_proc")
      } else c("processing_class")
    }
  )
  object <- list(model = list(), tokenizer = list(), max_seq_length = 32L)
  dataset <- list()
  unsloth_train(object, dataset, train_on_responses_only = TRUE)
  expect_identical(events, c("training_mode", "build", "mask", "train"))
})
