test_that("loading the package does not initialize Python", {
  testthat::skip_if(reticulate::py_available(initialize = FALSE),
                    "Python already initialized by another test")
  expect_false(reticulate::py_available(initialize = FALSE))
})

test_that("delayed module bindings exist in the namespace", {
  expect_true(exists("trl", envir = asNamespace("runsloth")))
})
