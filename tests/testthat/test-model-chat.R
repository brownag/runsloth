test_that("model wrappers preserve class and enforce token-before-LoRA order", {
  unsloth_mock <- list(FastLanguageModel = list(
    from_pretrained = function(model_name, max_seq_length, load_in_4bit) {
      list("model", "tokenizer")
    },
    get_peft_model = function(model, ...) model,
    add_new_tokens = function(model, tokenizer, new_tokens) {
      list(model, c(tokenizer, new_tokens))
    }
  ))
  local_mocked_bindings(unsloth = unsloth_mock)
  model <- unsloth_load_model(load_in_8bit = FALSE)
  expect_s3_class(model, "runsloth_model")
  expect_error(
    unsloth_load_model(load_in_4bit = TRUE, load_in_8bit = TRUE),
    class = "rlang_error"
  )
  updated <- unsloth_add_tokens(model, "extra")
  expect_identical(updated$tokenizer, list("tokenizer", "extra"))
  model$has_lora <- TRUE
  expect_error(unsloth_add_tokens(model, "new"), class = "rlang_error")
})

test_that("chat mapping uses the configured conversation column", {
  captured <- NULL
  dataset <- list(map = function(fn, batched) {
    fn(list(dialog = list("turn")))
  })
  local_mocked_bindings(
    unsloth = list(chat_templates = list()),
    datasets = list(Dataset = list(from_dict = function(x) {
      captured <<- x
      dataset
    }))
  )
  object <- list(tokenizer = list(apply_chat_template = function(x, ...) x))
  result <- unsloth_apply_chat_template(
    object, list(list(role = "user", content = "hi")),
    conversations_col = "dialog", standardize_sharegpt = FALSE)
  expect_named(captured, "dialog")
  expect_identical(result$text, list("turn"))
})

test_that("response masking only forwards supplied delimiters", {
  received <- NULL
  local_mocked_bindings(unsloth = list(trainer = list(
    train_on_responses_only = function(trainer, ...) {
      received <<- list(...)
      trainer
    }
  )))
  trainer <- list()
  expect_identical(unsloth_train_on_responses_only(trainer), trainer)
  expect_length(received, 0L)
  unsloth_train_on_responses_only(
    trainer, instruction_part = "### User:", response_part = "### Assistant:")
  expect_named(received, c("instruction_part", "response_part"))
})
