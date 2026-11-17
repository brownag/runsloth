test_that("GRPO reward bridge validates R callbacks and Python names", {
  expect_error(as_grpo_reward(1), class = "rlang_error")
  expect_error(as_grpo_reward(identity, name = "bad-name"), class = "rlang_error")
  expect_error(as_grpo_reward(identity, pass_kwargs = NA), class = "rlang_error")
})

test_that("GRPO reward bridge returns scalar results as lists and forwards kwargs", {
  available <- tryCatch(reticulate::py_module_available("unsloth"),
                        error = function(e) FALSE)
  skip_if(!isTRUE(available), "Python Unsloth integration is unavailable")
  scalar_reward <- as_grpo_reward(function(prompts, completions, answer) {
    expect_identical(answer, c("truth"))
    1
  }, pass_kwargs = TRUE)
  result <- reticulate::py_call(
    scalar_reward,
    list(prompts = c("prompt"), completions = c("completion")),
    keywords = list(answer = c("truth"))
  )
  expect_type(result, "list")
  expect_equal(unlist(result), 1)

  list_reward <- as_grpo_reward(function(prompts, completions) c(1, 2))
  result <- reticulate::py_call(
    list_reward,
    list(prompts = c("prompt"), completions = c("completion"))
  )
  expect_type(result, "list")
  expect_equal(unlist(result), c(1, 2))
})

test_that("GRPO training preserves reward function lists", {
  expect_identical(as.list(list(identity)), list(identity))
  reward_funcs <- identity
  if (!is.list(reward_funcs)) reward_funcs <- list(reward_funcs)
  expect_identical(reward_funcs, list(identity))
})
