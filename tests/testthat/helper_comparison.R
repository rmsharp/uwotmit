# Comparison utility functions for uwotlite vs uwot testing

# Skip helper for uwot comparison tests
skip_if_no_uwot <- function() {
  testthat::skip_if_not(
    requireNamespace("uwot", quietly = TRUE),
    "Package 'uwot' not installed"
  )
}

# Compute k-nearest neighbor indices for a data matrix
# Returns an n x k matrix of neighbor indices
compute_knn_indices <- function(X, k = 10) {
  n <- nrow(X)
  D <- as.matrix(stats::dist(X))
  t(apply(D, 1, function(row) order(row)[2:(k + 1)]))
}

# Trustworthiness: measures how well local neighborhoods are preserved
# High values (close to 1) indicate good preservation of local structure
# Formula: 1 - (2 / (n * k * (2*n - 3*k - 1))) * sum(rank penalties)
trustworthiness <- function(X_high, X_low, k = 10) {
  n <- nrow(X_high)
  if (k >= n) k <- n - 1

  # Get k-nearest neighbors in both spaces
  nn_high <- compute_knn_indices(X_high, k)
  nn_low <- compute_knn_indices(X_low, k)

  # For each point, compute rank of neighbors in high-dim that aren't in low-dim k-NN
  penalty <- 0
  for (i in seq_len(n)) {
    high_neighbors <- nn_high[i, ]
    low_neighbors <- nn_low[i, ]

    # Find points in low-dim neighbors not in high-dim neighbors
    false_neighbors <- setdiff(low_neighbors, high_neighbors)

    if (length(false_neighbors) > 0) {
      # Get ranks in high-dimensional space
      D_high <- as.matrix(stats::dist(X_high))
      ranks <- rank(D_high[i, ])
      penalty <- penalty + sum(pmax(0, ranks[false_neighbors] - k))
    }
  }

  # Normalize
  normalization <- n * k * (2 * n - 3 * k - 1)
  if (normalization <= 0) return(1)

  1 - (2 / normalization) * penalty
}

# Continuity: measures how well embedding preserves original neighborhoods
# High values (close to 1) indicate neighbors in high-dim stay close in low-dim
continuity <- function(X_high, X_low, k = 10) {
  n <- nrow(X_high)
  if (k >= n) k <- n - 1

  nn_high <- compute_knn_indices(X_high, k)
  nn_low <- compute_knn_indices(X_low, k)

  penalty <- 0
  for (i in seq_len(n)) {
    high_neighbors <- nn_high[i, ]
    low_neighbors <- nn_low[i, ]

    # Find points in high-dim neighbors not in low-dim neighbors
    missing_neighbors <- setdiff(high_neighbors, low_neighbors)

    if (length(missing_neighbors) > 0) {
      D_low <- as.matrix(stats::dist(X_low))
      ranks <- rank(D_low[i, ])
      penalty <- penalty + sum(pmax(0, ranks[missing_neighbors] - k))
    }
  }

  normalization <- n * k * (2 * n - 3 * k - 1)
  if (normalization <= 0) return(1)

  1 - (2 / normalization) * penalty
}

# Neighborhood preservation (Jaccard similarity of k-NN sets)
# Returns mean Jaccard similarity across all points
neighborhood_preservation <- function(X_high, X_low, k = 10) {
  n <- nrow(X_high)
  if (k >= n) k <- n - 1

  nn_high <- compute_knn_indices(X_high, k)
  nn_low <- compute_knn_indices(X_low, k)

  jaccard_similarities <- numeric(n)
  for (i in seq_len(n)) {
    intersection <- length(intersect(nn_high[i, ], nn_low[i, ]))
    union <- length(union(nn_high[i, ], nn_low[i, ]))
    jaccard_similarities[i] <- if (union > 0) intersection / union else 1
  }

  mean(jaccard_similarities)
}

# Distance correlation between two embeddings
# Measures how well pairwise distances are preserved
distance_correlation <- function(embed1, embed2) {
  D1 <- as.vector(stats::dist(embed1))
  D2 <- as.vector(stats::dist(embed2))

  if (length(D1) < 2) return(1)

  stats::cor(D1, D2, method = "spearman")
}

# Compare two embeddings with comprehensive metrics
# Returns a named list with quality metrics and comparison results
compare_embeddings <- function(embed1, embed2, original_data, k = 10,
                               labels = c("embed1", "embed2")) {
  # Individual quality metrics
  trust1 <- trustworthiness(original_data, embed1, k = k)
  trust2 <- trustworthiness(original_data, embed2, k = k)

  cont1 <- continuity(original_data, embed1, k = k)
  cont2 <- continuity(original_data, embed2, k = k)

  np1 <- neighborhood_preservation(original_data, embed1, k = k)
  np2 <- neighborhood_preservation(original_data, embed2, k = k)

  # Distance correlation between the two embeddings
  dist_cor <- distance_correlation(embed1, embed2)

  list(
    trustworthiness = stats::setNames(c(trust1, trust2), labels),
    continuity = stats::setNames(c(cont1, cont2), labels),
    neighborhood_preservation = stats::setNames(c(np1, np2), labels),
    distance_correlation = dist_cor,
    trust_diff = abs(trust1 - trust2),
    cont_diff = abs(cont1 - cont2),
    np_diff = abs(np1 - np2)
  )
}

# Check if both embeddings meet quality thresholds
# Used for statistical similarity tests
embeddings_similar <- function(comparison_result,
                               min_trustworthiness = 0.85,
                               max_trust_diff = 0.1,
                               min_dist_cor = 0.7) {
  trust_ok <- all(comparison_result$trustworthiness >= min_trustworthiness)
  diff_ok <- comparison_result$trust_diff <= max_trust_diff
  cor_ok <- comparison_result$distance_correlation >= min_dist_cor

  list(
    pass = trust_ok && diff_ok && cor_ok,
    trust_ok = trust_ok,
    diff_ok = diff_ok,
    cor_ok = cor_ok
  )
}

# Format comparison results for test output
format_comparison_results <- function(comparison_result, labels = c("uwotlite", "uwot")) {
  paste0(
    "Quality Metrics:\n",
    sprintf("  Trustworthiness: %s=%.4f, %s=%.4f (diff=%.4f)\n",
            labels[1], comparison_result$trustworthiness[1],
            labels[2], comparison_result$trustworthiness[2],
            comparison_result$trust_diff),
    sprintf("  Continuity: %s=%.4f, %s=%.4f (diff=%.4f)\n",
            labels[1], comparison_result$continuity[1],
            labels[2], comparison_result$continuity[2],
            comparison_result$cont_diff),
    sprintf("  Neighborhood Preservation: %s=%.4f, %s=%.4f (diff=%.4f)\n",
            labels[1], comparison_result$neighborhood_preservation[1],
            labels[2], comparison_result$neighborhood_preservation[2],
            comparison_result$np_diff),
    sprintf("  Distance Correlation: %.4f\n", comparison_result$distance_correlation)
  )
}

# Test data generator - creates reproducible test datasets
create_comparison_data <- function(n = 100, p = 10, seed = 42) {
  set.seed(seed)

  # Create clustered data for more interesting UMAP results
  n_per_cluster <- n %/% 3
  remainder <- n %% 3

  cluster1 <- matrix(rnorm(n_per_cluster * p, mean = 0), ncol = p)

cluster2 <- matrix(rnorm(n_per_cluster * p, mean = 3), ncol = p)
  cluster3 <- matrix(rnorm((n_per_cluster + remainder) * p, mean = -3), ncol = p)

  X <- rbind(cluster1, cluster2, cluster3)
  labels <- factor(c(
    rep("A", n_per_cluster),
    rep("B", n_per_cluster),
    rep("C", n_per_cluster + remainder)
  ))

  list(X = X, labels = labels)
}
