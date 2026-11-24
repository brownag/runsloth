test_that("loading the package does not initialize Python", {
  testthat::skip_if(reticulate::py_available(initialize = FALSE),
                    "Python already initialized by another test")
  expect_false(reticulate::py_available(initialize = FALSE))
})

test_that(".onLoad binds delayed module proxies", {
  ns <- asNamespace("runsloth")
  for (name in c("unsloth", "trl", "datasets", "transformers", "torch", "inspect")) {
    expect_s3_class(get(name, envir = ns), "python.builtin.module")
  }
})
