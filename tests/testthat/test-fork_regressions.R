# =============================================================================
# Fork-Specific Regression Tests for uwotlite
# These tests verify the critical differences between uwotlite and uwot
# to prevent regressions in fork-specific behavior.
#
# Key fork changes:
# 1. Replaced AGPL-licensed dqrng with MIT-licensed sitmo for PCG RNG
# 2. Custom convert_seed() function replacing dqrng::convert_seed
# 3. All RNG types (pcg, tausworthe, deterministic) must work correctly
# =============================================================================

# Helper for test data
iris10 <- as.matrix(iris[1:10, 1:4])
iris50 <- as.matrix(iris[1:50, 1:4])
iris100 <- as.matrix(iris[1:100, 1:4])

# =============================================================================
# Section 1: RNG Reproducibility Tests (CRITICAL)
# The fork replaces dqrng with sitmo - must verify reproducibility
# =============================================================================

test_that("PCG RNG (via sitmo) produces reproducible results with same seed", {
  # This is CRITICAL - verifies sitmo replacement of dqrng works correctly
  set.seed(42)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  set.seed(42)
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2,
    info = "CRITICAL: PCG RNG with sitmo must be reproducible with same seed")
})

test_that("Tausworthe RNG produces reproducible results with same seed", {
  set.seed(123)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "tausworthe", n_threads = 1, verbose = FALSE)

  set.seed(123)
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "tausworthe", n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2,
    info = "Tausworthe RNG must be reproducible with same seed")
})

test_that("Deterministic RNG produces identical results regardless of seed", {
  # "deterministic" RNG only affects vertex sampling during optimization.
  # To get truly seed-independent results, we also need fixed initialization.
  # Without fixed initialization, R's seed affects PCA/spectral init and NN search.
  # With init = "spca" (scaled PCA) and scale = FALSE, we remove R seed dependence.

  # Pre-compute initialization to ensure it's identical
  init_pca <- prcomp(iris50, center = TRUE, scale. = FALSE, rank. = 2)$x

  set.seed(999)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 20, init = init_pca,
                  scale = FALSE, rng_type = "deterministic", n_threads = 0,
                  verbose = FALSE)

  set.seed(111)  # Different seed
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 20, init = init_pca,
                  scale = FALSE, rng_type = "deterministic", n_threads = 0,
                  verbose = FALSE)

  expect_equal(result1, result2,
    info = "Deterministic RNG with fixed init should produce same results regardless of seed")
})

test_that("Different seeds produce different results for PCG", {
  set.seed(100)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  set.seed(200)  # Different seed
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  # Results should differ with different seeds
  expect_false(identical(result1, result2),
    info = "Different seeds should produce different results")
})

test_that("Different seeds produce different results for Tausworthe", {
  set.seed(300)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "tausworthe", n_threads = 1, verbose = FALSE)

  set.seed(400)  # Different seed
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "tausworthe", n_threads = 1, verbose = FALSE)

  expect_false(identical(result1, result2),
    info = "Different seeds should produce different results")
})

# =============================================================================
# Section 2: Different RNG Types Produce Different Results
# Verifies that each RNG algorithm is distinct
# =============================================================================

test_that("Different RNG types produce different results with same seed", {
  set.seed(500)
  result_pcg <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                     rng_type = "pcg", n_threads = 1, verbose = FALSE)

  set.seed(500)
  result_tau <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                     rng_type = "tausworthe", n_threads = 1, verbose = FALSE)

  set.seed(500)
  result_det <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                     rng_type = "deterministic", n_threads = 1, verbose = FALSE)

  # All three should be different (different algorithms)
  expect_false(identical(result_pcg, result_tau),
    info = "PCG and Tausworthe should produce different results")
  expect_false(identical(result_pcg, result_det),
    info = "PCG and Deterministic should produce different results")
  expect_false(identical(result_tau, result_det),
    info = "Tausworthe and Deterministic should produce different results")
})

test_that("All RNG types produce valid embeddings", {
  for (rng in c("pcg", "tausworthe", "deterministic")) {
    set.seed(42)
    result <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                   rng_type = rng, n_threads = 1, verbose = FALSE)

    expect_equal(nrow(result), 50,
      info = paste("RNG type", rng, "should produce correct number of rows"))
    expect_equal(ncol(result), 2,
      info = paste("RNG type", rng, "should produce correct number of columns"))
    expect_false(anyNA(result),
      info = paste("RNG type", rng, "should not produce NA values"))
  }
})

# =============================================================================
# Section 3: convert_seed() Function (Indirect Testing)
# The custom convert_seed() in rng.h replaces dqrng::convert_seed
# We test it indirectly through UMAP reproducibility
# =============================================================================

test_that("Seed conversion produces consistent results across calls", {
  # Run multiple times with same seed to verify convert_seed works
  results <- lapply(1:3, function(i) {
    set.seed(777)
    umap(iris50, n_neighbors = 10, n_epochs = 10,
         rng_type = "pcg", n_threads = 1, verbose = FALSE)
  })

  # All should be identical
  expect_equal(results[[1]], results[[2]])
  expect_equal(results[[2]], results[[3]])
})

test_that("Large seed values work correctly", {
  # Test with large seed to verify uint64 handling in convert_seed
  set.seed(.Machine$integer.max)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  set.seed(.Machine$integer.max)
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 10,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2,
    info = "Large seed values should work correctly")
  expect_equal(nrow(result1), 50)
  expect_false(anyNA(result1))
})

# =============================================================================
# Section 4: Threading + RNG Stability
# =============================================================================

test_that("RNG is reproducible with n_threads = 0 (no parallelism)", {
  set.seed(888)
  result1 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "pcg", n_threads = 0, verbose = FALSE)

  set.seed(888)
  result2 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                  rng_type = "pcg", n_threads = 0, verbose = FALSE)

  expect_equal(result1, result2)
})

test_that("Single-threaded vs no-threading produces same results", {
  set.seed(999)
  result_t0 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                    rng_type = "deterministic", n_threads = 0, verbose = FALSE)

  set.seed(999)
  result_t1 <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                    rng_type = "deterministic", n_threads = 1, verbose = FALSE)

  expect_equal(result_t0, result_t1,
    info = "Deterministic RNG should produce same results regardless of thread setting")
})

# =============================================================================
# Section 5: Backwards Compatibility (pcg_rand parameter)
# =============================================================================

test_that("pcg_rand = TRUE behaves like rng_type = 'pcg'", {
  set.seed(555)
  result_param <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                       pcg_rand = TRUE, n_threads = 1, verbose = FALSE)

  set.seed(555)
  result_rng <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                     rng_type = "pcg", n_threads = 1, verbose = FALSE)

  expect_equal(result_param, result_rng,
    info = "pcg_rand = TRUE should behave like rng_type = 'pcg'")
})

test_that("pcg_rand = FALSE uses tausworthe", {
  set.seed(666)
  result_param <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                       pcg_rand = FALSE, n_threads = 1, verbose = FALSE)

  set.seed(666)
  result_rng <- umap(iris50, n_neighbors = 10, n_epochs = 20,
                     rng_type = "tausworthe", n_threads = 1, verbose = FALSE)

  expect_equal(result_param, result_rng,
    info = "pcg_rand = FALSE should use tausworthe")
})

# =============================================================================
# Section 6: Edge Cases
# =============================================================================

test_that("UMAP works with minimum n_neighbors = 2", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 2, n_epochs = 10,
                 rng_type = "deterministic", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  expect_equal(ncol(result), 2)
  expect_false(anyNA(result))
})

test_that("UMAP works with very small dataset", {
  small_data <- iris10
  set.seed(42)
  result <- umap(small_data, n_neighbors = 3, n_epochs = 10,
                 rng_type = "deterministic", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 10)
  expect_equal(ncol(result), 2)
  expect_false(anyNA(result))
})

test_that("UMAP works with min_dist = 0", {
  set.seed(42)
  result <- umap(iris50, n_neighbors = 10, n_epochs = 10, min_dist = 0,
                 rng_type = "deterministic", n_threads = 1, verbose = FALSE)

  expect_equal(nrow(result), 50)
  expect_equal(ncol(result), 2)
  expect_false(anyNA(result))
})

test_that("UMAP works with high n_components", {
  # Request more components than input dimensions - warning is expected
  set.seed(42)
  result <- suppressWarnings(
    umap(iris50, n_neighbors = 10, n_epochs = 10, n_components = 10,
         rng_type = "deterministic", n_threads = 1, verbose = FALSE)
  )

  expect_equal(nrow(result), 50)
  expect_equal(ncol(result), 10)
  expect_false(anyNA(result))
})

# =============================================================================
# Section 7: Transform Function RNG
# =============================================================================

test_that("umap_transform is reproducible with same seed", {
  train_data <- iris[1:100, 1:4]
  test_data <- iris[101:120, 1:4]

  set.seed(42)
  model <- umap(as.matrix(train_data), n_neighbors = 10, n_epochs = 20,
                rng_type = "pcg", ret_model = TRUE, n_threads = 1, verbose = FALSE)

  set.seed(123)
  result1 <- umap_transform(as.matrix(test_data), model = model,
                            n_threads = 1, verbose = FALSE)

  set.seed(123)
  result2 <- umap_transform(as.matrix(test_data), model = model,
                            n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2,
    info = "umap_transform should be reproducible with same seed")
})

# =============================================================================
# Section 8: tumap and lvish with RNG
# =============================================================================

test_that("tumap is reproducible with same seed", {
  set.seed(42)
  result1 <- tumap(iris50, n_neighbors = 10, n_epochs = 20,
                   n_threads = 1, verbose = FALSE)

  set.seed(42)
  result2 <- tumap(iris50, n_neighbors = 10, n_epochs = 20,
                   n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2)
})

test_that("lvish is reproducible with same seed", {
  # lvish uses perplexity (t-SNE style), which must be < n-1
  # For 50 observations, perplexity must be < 49
  set.seed(42)
  result1 <- lvish(iris50, perplexity = 15, n_epochs = 20,
                   n_threads = 1, verbose = FALSE)

  set.seed(42)
  result2 <- lvish(iris50, perplexity = 15, n_epochs = 20,
                   n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2)
})

# =============================================================================
# Section 9: Supervised UMAP with RNG
# =============================================================================

test_that("Supervised UMAP is reproducible with same seed", {
  labels <- iris$Species[1:50]

  set.seed(42)
  result1 <- umap(iris50, y = labels, n_neighbors = 10, n_epochs = 20,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  set.seed(42)
  result2 <- umap(iris50, y = labels, n_neighbors = 10, n_epochs = 20,
                  rng_type = "pcg", n_threads = 1, verbose = FALSE)

  expect_equal(result1, result2,
    info = "Supervised UMAP should be reproducible with same seed")
})

# =============================================================================
# Section 10: Package Identity
# =============================================================================

test_that("Package is uwotlite, not uwot", {
  expect_true(
    "uwotlite" %in% loadedNamespaces() ||
    requireNamespace("uwotlite", quietly = TRUE)
  )
})
