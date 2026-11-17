test_that("vision dataset inputs are validated before Python is used", {
  expect_error(as_vision_dataset(character(), character(), character()),
               class = "rlang_error")
  expect_error(as_vision_dataset("missing-image.png", "look", "cat"),
               class = "rlang_error")
  path <- tempfile()
  writeBin(as.raw(1), path)
  on.exit(unlink(path))
  expect_error(as_vision_dataset(path, character(), "cat"),
               class = "rlang_error")
  expect_error(as_vision_dataset(path, "look", "cat", max_size_img = 0),
               class = "rlang_error")
})

test_that("vision LoRA and training reject non-vision wrappers", {
  expect_error(unsloth_add_vision_lora(list(model = NULL)),
               class = "rlang_error")
  expect_error(unsloth_train_vision(list(model = NULL), list()),
               class = "rlang_error")
})

test_that("vision dataset construction works with an available local PIL", {
  skip_if(!reticulate::py_available(initialize = FALSE),
          "Python is not already configured")
  skip_if_not(reticulate::py_module_available("PIL"))
  skip_if_not_installed("png")
  path <- tempfile(fileext = ".png")
  on.exit(unlink(path))
  png::writePNG(array(1, dim = c(4, 5, 1)), path)
  result <- as_vision_dataset(path, "Describe this", "A small image", 3L)
  expect_length(result, 1L)
  expect_length(result[[1L]], 2L)
})
