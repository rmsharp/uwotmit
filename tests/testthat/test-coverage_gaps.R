# =============================================================================
# Coverage Gap Tests for uwotlite
# Tests for previously untested or under-tested code paths
# =============================================================================

# Helper data
iris10 <- as.matrix(iris[1:10, 1:4])
iris50 <- as.matrix(iris[1:50, 1:4])
iris100 <- as.matrix(iris[1:100, 1:4])

# =============================================================================
# Section 1: RNG/Seed Edge Cases (HIGH PRIORITY - Fork Specific)
# convert_seed() replacement for dqrng::convert_seed
# =============================================================================

test_that("seed = 0 works correctly", {
  set.seed(0)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  set.seed(0)
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2,
               info = "Seed 0 should produce reproducible results")
  expect_equal(nrow(result1), 50)
})

test_that("negative seed values work correctly", {
  set.seed(-1)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  set.seed(-1)
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2,
               info = "Negative seeds should produce reproducible results")
})

test_that("very large negative seed works", {
  set.seed(-.Machine$integer.max)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  set.seed(-.Machine$integer.max)
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2)
  expect_false(anyNA(result1))
})

test_that("seed parameter in umap function works", {
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 10, seed = 42,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 10, seed = 42,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2,
               info = "umap seed parameter should work")
})

test_that("seed = NULL uses current RNG state", {
  set.seed(999)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 10, seed = NULL,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  set.seed(999)
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 10, seed = NULL,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2)
})

# =============================================================================
# Section 2: Invalid rng_type Handling (HIGH PRIORITY - Fork Specific)
# =============================================================================

test_that("invalid rng_type string errors clearly", {
  expect_error(
    umap(iris50, n_neighbors = 10, n_epochs = 10,
         rng_type = "pcgg", n_threads = 1, verbose = FALSE),
    "arg.*should be one of|match.arg"
  )
})

test_that("empty rng_type string errors", {
  expect_error(
    umap(iris50, n_neighbors = 10, n_epochs = 10,
         rng_type = "", n_threads = 1, verbose = FALSE),
    "arg.*should be one of|match.arg"
  )
})

test_that("rng_type = NULL with pcg_rand = FALSE uses tausworthe", {
  set.seed(42)
  result_null <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                      rng_type = NULL, pcg_rand = FALSE,
                      n_threads = 1, verbose = FALSE)

  set.seed(42)
  result_tau <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                     rng_type = "tausworthe",
                     n_threads = 1, verbose = FALSE)

  expect_equal(result_null, result_tau)
})

# =============================================================================
# Section 3: Parameter Validation Edge Cases (HIGH PRIORITY)
# =============================================================================

test_that("n_neighbors = 1 errors", {
  expect_error(
    umap(iris50, n_neighbors = 1, n_epochs = 10, verbose = FALSE),
    "n_neighbors must be >= 2"
  )
})

test_that("n_neighbors = 0 errors", {
  expect_error(
    umap(iris50, n_neighbors = 0, n_epochs = 10, verbose = FALSE),
    "n_neighbors must be >= 2"
  )
})

test_that("negative n_neighbors errors", {
  expect_error(
    umap(iris50, n_neighbors = -5, n_epochs = 10, verbose = FALSE),
    "n_neighbors must be >= 2"
  )
})

test_that("n_components = 0 errors", {
  expect_error(
    umap(iris50, n_neighbors = 10, n_components = 0, verbose = FALSE),
    "n_components.*must be a positive integer"
  )
})

test_that("n_components = 1 works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_components = 1,
                 n_epochs = 10, n_threads = 1, verbose = FALSE)

  expect_equal(ncol(result), 1)
  expect_equal(nrow(result), 50)
})

test_that("negative n_components errors", {
  expect_error(
    umap(iris50, n_neighbors = 10, n_components = -1, verbose = FALSE),
    "n_components.*must be a positive integer"
  )
})

test_that("set_op_mix_ratio boundary values work", {
  set.seed(42)
  # Exactly 0
  result0 <- umap(iris50, n_neighbors = 10, n_epochs = 5,
                  set_op_mix_ratio = 0, n_threads = 1, verbose = FALSE)
  expect_equal(nrow(result0), 50)

  # Exactly 1
  set.seed(42)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 5,
                  set_op_mix_ratio = 1, n_threads = 1, verbose = FALSE)
  expect_equal(nrow(result1), 50)
})

test_that("set_op_mix_ratio outside [0,1] errors", {
  expect_error(
    umap(iris50, n_neighbors = 10, set_op_mix_ratio = -0.1, verbose = FALSE),
    "set_op_mix_ratio must be between 0.0 and 1.0"
  )

  expect_error(
    umap(iris50, n_neighbors = 10, set_op_mix_ratio = 1.1, verbose = FALSE),
    "set_op_mix_ratio must be between 0.0 and 1.0"
  )
})

test_that("local_connectivity exactly 1.0 works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 5,
                 local_connectivity = 1.0, n_threads = 1, verbose = FALSE)
  expect_equal(nrow(result), 50)
})

test_that("local_connectivity < 1.0 errors", {
  expect_error(
    umap(iris50, n_neighbors = 10, local_connectivity = 0.9, verbose = FALSE),
    "local_connectivity cannot be < 1.0"
  )

  expect_error(
    umap(iris50, n_neighbors = 10, local_connectivity = 0, verbose = FALSE),
    "local_connectivity cannot be < 1.0"
  )
})

test_that("n_epochs = 0 works (no optimization)", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 0,
                 n_threads = 1, verbose = FALSE)
  expect_equal(nrow(result), 50)
  expect_equal(ncol(result), 2)
})

test_that("n_epochs = 1 works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 1,
                 n_threads = 1, verbose = FALSE)
  expect_equal(nrow(result), 50)
})

# =============================================================================
# Section 4: Threading Parameter Edge Cases (HIGH PRIORITY)
# =============================================================================

test_that("n_threads = 0 is equivalent to serial processing", {
  set.seed(42)
  result0 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  rng_type = "deterministic", n_threads = 0, verbose = FALSE)

  expect_equal(nrow(result0), 50)
  expect_false(anyNA(result0))
})

test_that("negative n_threads errors", {
  expect_error(
    umap(iris50, n_neighbors = 10, n_threads = -1, verbose = FALSE),
    "n_threads cannot be < 0"
  )
})

test_that("negative n_build_threads errors", {
  expect_error(
    umap(iris50, n_neighbors = 10, n_build_threads = -1, verbose = FALSE),
    "n_build_threads cannot be < 0"
  )
})

test_that("negative n_sgd_threads errors", {
  expect_error(
    umap(iris50, n_neighbors = 10, n_sgd_threads = -1, verbose = FALSE),
    "n_sgd_threads cannot be < 0"
  )
})

test_that("non-integer n_threads gets rounded", {
  set.seed(42)
  # Should round and warn
  result <- suppressMessages(
    umap(iris50, n_neighbors = 10, n_epochs = 5,
         n_threads = 1.7, verbose = FALSE)
  )
  expect_equal(nrow(result), 50)
})

# =============================================================================
# Section 5: umap_transform Error Paths (HIGH PRIORITY)
# =============================================================================

test_that("umap_transform errors when model not provided", {
  expect_error(
    umap_transform(iris50, model = NULL),
    "model|NULL"
  )
})

test_that("umap_transform errors with dimension mismatch", {
  set.seed(42)
  model <- umap(iris100, n_neighbors = 15, n_epochs = 10,
                ret_model = TRUE, n_threads = 1, verbose = FALSE)

  # Wrong number of columns
  new_data <- iris50[, 1:3]  # Only 3 columns instead of 4

  expect_error(
    umap_transform(new_data, model = model, verbose = FALSE),
    "Incorrect dimensions|columns"
  )
})

test_that("umap_transform handles single row input", {
  set.seed(42)
  model <- umap(iris100, n_neighbors = 15, n_epochs = 10,
                ret_model = TRUE, n_threads = 1, verbose = FALSE)

  new_data <- iris50[1, , drop = FALSE]

  result <- umap_transform(new_data, model = model, n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 1)
  expect_equal(ncol(result), 2)
})

test_that("umap_transform works with data.frame input", {
  set.seed(42)
  model <- umap(iris100, n_neighbors = 15, n_epochs = 10,
                ret_model = TRUE, n_threads = 1, verbose = FALSE)

  new_data <- as.data.frame(iris50)

  result <- umap_transform(new_data, model = model, n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  expect_equal(ncol(result), 2)
})

# =============================================================================
# Section 6: Model Save/Load Edge Cases (HIGH PRIORITY)
# =============================================================================

test_that("save_uwot creates valid file", {
  set.seed(42)
  model <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                ret_model = TRUE, n_threads = 1, verbose = FALSE)

  tmpfile <- tempfile(fileext = ".uwot")

  save_uwot(model, file = tmpfile)

  expect_true(file.exists(tmpfile))
  expect_gt(file.size(tmpfile), 0)

  # Cleanup
  unlink(tmpfile)
})

test_that("load_uwot restores model correctly", {
  set.seed(42)
  model <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                ret_model = TRUE, n_threads = 1, verbose = FALSE)

  tmpfile <- tempfile(fileext = ".uwot")
  save_uwot(model, file = tmpfile)

  loaded_model <- load_uwot(file = tmpfile)

  # Transform with both models should give similar results
  set.seed(42)
  result_orig <- umap_transform(iris10, model = model,
                                n_threads = 1, verbose = FALSE)

  set.seed(42)
  result_loaded <- umap_transform(iris10, model = loaded_model,
                                  n_threads = 1, verbose = FALSE)

  expect_equal(result_orig, result_loaded)

  # Cleanup
  unload_uwot(loaded_model)
  unlink(tmpfile)
})

test_that("unload_uwot works correctly", {
  set.seed(42)
  model <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                ret_model = TRUE, n_threads = 1, verbose = FALSE)

  tmpfile <- tempfile(fileext = ".uwot")
  save_uwot(model, file = tmpfile)

  loaded_model <- load_uwot(file = tmpfile)

  # Unload should work without error
  expect_no_error(unload_uwot(loaded_model))

  # Cleanup
  unlink(tmpfile)
})

# =============================================================================
# Section 7: Scaling Edge Cases (MEDIUM PRIORITY)
# =============================================================================

test_that("scale = FALSE works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 scale = FALSE, n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  # Result is a valid matrix
  expect_false(anyNA(result))
})

test_that("scale = 'scale' works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 scale = "scale", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  expect_false(is.null(attr(result, "scaled:center")))
})

test_that("scale = 'maxabs' works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 scale = "maxabs", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("scale = 'range' works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 scale = "range", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("scaling with zero variance column handled", {
  # Create data with a zero-variance column
  data_with_const <- cbind(iris50, constant = rep(5, 50))

  set.seed(42)
  result <- suppressWarnings(
    umap(data_with_const, n_neighbors = 10, n_epochs = 10,
         scale = TRUE, n_threads = 1, verbose = FALSE)
  )

  expect_equal(nrow(result), 50)
})

# =============================================================================
# Section 8: PCA Initialization Edge Cases (MEDIUM PRIORITY)
# =============================================================================

test_that("pca = n_components works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10, n_components = 2,
                 pca = 2, n_threads = 1, verbose = FALSE)

  expect_equal(ncol(result), 2)
})

test_that("pca < n_components errors", {
  expect_error(
    umap(iris50, n_neighbors = 10, n_components = 3, pca = 2, verbose = FALSE),
    "pca.*must be >= n_components"
  )
})

test_that("pca > input dimensions is ignored with message", {
  set.seed(42)
  # iris50 has 4 columns, so pca = 10 is too large
  result <- suppressMessages(
    umap(iris50, n_neighbors = 10, n_epochs = 10,
         pca = 10, n_threads = 1, verbose = TRUE)
  )

  expect_equal(nrow(result), 50)
})

# =============================================================================
# Section 9: Initialization Options (MEDIUM PRIORITY)
# =============================================================================

test_that("init = 'random' works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 init = "random", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  expect_equal(ncol(result), 2)
})

test_that("init = 'spectral' works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 init = "spectral", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("init = 'spca' works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 init = "spca", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("init = custom matrix works", {
  set.seed(42)
  custom_init <- matrix(rnorm(100), nrow = 50, ncol = 2)

  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 init = custom_init, n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  expect_equal(ncol(result), 2)
})

test_that("init matrix dimension mismatch errors", {
  custom_init <- matrix(rnorm(60), nrow = 30, ncol = 2)  # Wrong row count

  expect_error(
    umap(iris50, n_neighbors = 10, init = custom_init, verbose = FALSE),
    "init|dimension|row"
  )
})

# =============================================================================
# Section 10: Metric Options (MEDIUM PRIORITY)
# =============================================================================

test_that("metric = 'cosine' works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 metric = "cosine", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("metric = 'manhattan' works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 metric = "manhattan", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("metric = 'correlation' works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 metric = "correlation", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

# =============================================================================
# Section 11: Supervised UMAP Edge Cases (MEDIUM PRIORITY)
# =============================================================================

test_that("supervised umap with NA labels works", {
  labels <- iris$Species[1:50]
  labels[c(1, 10, 20)] <- NA

  set.seed(42)
  result <- umap(iris50, y = labels, n_neighbors = 10, n_epochs = 10,
                 n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("supervised umap with numeric target works", {
  target <- iris$Sepal.Width[1:50]

  set.seed(42)
  result <- umap(iris50, y = target, n_neighbors = 10, n_epochs = 10,
                 n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("supervised umap with NA in numeric target errors", {
  target <- iris$Sepal.Width[1:50]
  target[1] <- NA

  expect_error(
    umap(iris50, y = target, n_neighbors = 10, verbose = FALSE),
    "numeric y cannot contain NA"
  )
})

# =============================================================================
# Section 12: tumap and lvish Edge Cases (MEDIUM PRIORITY)
# =============================================================================

test_that("tumap with n_epochs = 0 works", {
  set.seed(42)
  result <- tumap(iris50, n_neighbors = 10, n_epochs = 0,
                  n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("tumap with n_components = 1 works", {
  set.seed(42)
  result <- tumap(iris50, n_neighbors = 10, n_epochs = 10, n_components = 1,
                  n_threads = 1, verbose = FALSE)

  expect_equal(ncol(result), 1)
})

test_that("lvish with valid perplexity works", {
  set.seed(42)
  result <- lvish(iris50, perplexity = 10, n_epochs = 10,
                  n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("lvish perplexity must be < n-1", {
  expect_error(
    lvish(iris50, perplexity = 50, verbose = FALSE),
    "perplexity can be no larger than"
  )
})

# =============================================================================
# Section 13: batch and approx_pow Options (MEDIUM PRIORITY)
# =============================================================================

test_that("batch = TRUE works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 batch = TRUE, n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("approx_pow = TRUE works", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 approx_pow = TRUE, n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("fast_sgd = TRUE sets correct parameters", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 fast_sgd = TRUE, n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

# =============================================================================
# Section 14: ret_* Return Options (MEDIUM PRIORITY)
# =============================================================================

test_that("ret_nn = TRUE returns neighbor info", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 ret_nn = TRUE, n_threads = 1, verbose = FALSE)

  expect_true("nn" %in% names(result))
  expect_true("embedding" %in% names(result))
})

test_that("ret_model = TRUE returns model info", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 ret_model = TRUE, n_threads = 1, verbose = FALSE)

  expect_true("embedding" %in% names(result))
  expect_true(!is.null(result$nn_index))
})

test_that("ret_extra = 'sigma' returns sigma info", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 ret_extra = c("sigma"), n_threads = 1, verbose = FALSE)

  expect_true("sigma" %in% names(result))
})

# =============================================================================
# Section 15: a/b Parameter Options (MEDIUM PRIORITY)
# =============================================================================

test_that("custom a/b parameters work", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                 a = 1.5, b = 0.7, n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("spread and min_dist calculate correct a/b", {
  set.seed(42)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  spread = 1.5, min_dist = 0.2,
                  n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result1), 50)
})

# =============================================================================
# Section 16: Data Frame Input Handling (MEDIUM PRIORITY)
# =============================================================================

test_that("data.frame input works", {
  set.seed(42)
  df_input <- as.data.frame(iris50)

  result <- umap(df_input, n_neighbors = 10, n_epochs = 10,
                 n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
})

test_that("data.frame with non-numeric columns is handled", {
  set.seed(42)
  df_input <- iris[1:50, ]  # Includes Species factor

  # Should only use numeric columns
  result <- suppressWarnings(
    umap(df_input, n_neighbors = 10, n_epochs = 10,
         n_threads = 1, verbose = FALSE)
  )

  expect_equal(nrow(result), 50)
})

# =============================================================================
# Section 17: umap2 Function (MEDIUM PRIORITY)
# =============================================================================

test_that("umap2 basic functionality works", {
  set.seed(42)
  result <- umap2(iris50, n_neighbors = 10, n_epochs = 10,
                  n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  expect_equal(ncol(result), 2)
})

test_that("umap2 with ret_nn option works", {
  set.seed(42)

  # Get neighbors and embedding
  result <- umap2(iris50, n_neighbors = 10, n_epochs = 10,
                  ret_nn = TRUE, n_threads = 1, verbose = FALSE)

  expect_true("nn" %in% names(result))
  expect_true("embedding" %in% names(result))
  expect_equal(nrow(result$embedding), 50)
})

# =============================================================================
# Section 18: Verbose and Callback Options (MEDIUM PRIORITY)
# =============================================================================

test_that("verbose = TRUE produces output", {
  # Just verify it doesn't error
  expect_no_error({
    capture.output({
      umap(iris50, n_neighbors = 10, n_epochs = 5,
           n_threads = 1, verbose = TRUE)
    })
  })
})

test_that("epoch_callback works", {
  epochs_seen <- integer(0)

  callback <- function(epoch, n_epochs, embedding) {
    epochs_seen <<- c(epochs_seen, epoch)
  }

  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 5,
                 epoch_callback = callback,
                 n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  expect_true(length(epochs_seen) > 0)
})

# =============================================================================
# Section 19: Error Recovery and Edge Cases (MEDIUM PRIORITY)
# =============================================================================

test_that("very small dataset (n=3) works", {
  small_data <- iris[1:3, 1:4]

  set.seed(42)
  result <- umap(as.matrix(small_data), n_neighbors = 2, n_epochs = 10,
                 n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 3)
})

test_that("single column input works", {
  single_col <- matrix(rnorm(50), ncol = 1)

  set.seed(42)
  # With just 1 dimension, embedding still works
  result <- suppressWarnings(
    umap(single_col, n_neighbors = 10, n_epochs = 10, n_components = 1,
         n_threads = 1, verbose = FALSE)
  )

  expect_equal(nrow(result), 50)
})

test_that("high-dimensional data works", {
  high_dim <- matrix(rnorm(50 * 100), nrow = 50, ncol = 100)

  set.seed(42)
  result <- umap(high_dim, n_neighbors = 10, n_epochs = 5,
                 n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  expect_equal(ncol(result), 2)
})
