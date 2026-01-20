# Dimensionality Reduction with UMAP

This vignette demonstrates UMAP (Uniform Manifold Approximation and
Projection) dimensionality reduction using `uwotmit`, as a complement to
the categorical encoding techniques shown in [Chapter 17 of Tidy
Modeling with R](https://www.tmwr.org/categorical).

## Introduction

While Chapter 17 of TMWR focuses on encoding categorical variables into
numeric representations, another common preprocessing task is
*dimensionality reduction*—transforming many features into fewer
features while preserving important structure.

UMAP is a nonlinear dimensionality reduction technique that:

- Preserves both local and global structure in data
- Scales well to large datasets
- Can be used for visualization (2D) or feature creation (higher
  dimensions)
- Supports supervised reduction using outcome information

The `uwotmit` package provides an MIT-licensed UMAP implementation.

## Setup

Code

``` r
library(uwotmit)
library(dplyr)
library(ggplot2)
library(modeldata)

# Load the Ames housing data
data(ames)

# Create train/test split
set.seed(502)
n <- nrow(ames)
train_idx <- sample(seq_len(n), size = floor(0.8 * n))
ames_train <- ames[train_idx, ]
ames_test <- ames[-train_idx, ]
```

## Preparing Numeric Features

After encoding categorical variables (using effect encodings as shown in
the `embedmit` vignette), you often have many numeric features. Let’s
prepare a numeric dataset from the Ames data:

Code

``` r
# Select numeric features
ames_numeric <- ames_train %>%
  select(
    Lot_Area, Gr_Liv_Area, Year_Built, Year_Remod_Add,
    Total_Bsmt_SF, First_Flr_SF, Second_Flr_SF,
    Full_Bath, Half_Bath, Bedroom_AbvGr, TotRms_AbvGrd,
    Fireplaces, Garage_Cars, Garage_Area,
    Wood_Deck_SF, Open_Porch_SF
  ) %>%
  # Handle missing values
  mutate(across(everything(), ~ifelse(is.na(.), median(., na.rm = TRUE), .))) %>%
  # Scale the features
  mutate(across(everything(), scale))

# Convert to matrix for uwotmit
ames_matrix <- as.matrix(ames_numeric)

dim(ames_matrix)
#> [1] 2344   16
```

The matrix contains our observations and 16 numeric features.

## Basic UMAP

The [`umap()`](https://rmsharp.github.io/uwotmit/reference/umap.md)
function performs dimensionality reduction:

Code

``` r
set.seed(123)
ames_umap <- umap(
  ames_matrix,
  n_neighbors = 15,
  n_components = 2,
  metric = "euclidean",
  min_dist = 0.1,
  verbose = FALSE
)

# Combine with price for visualization
umap_df <- data.frame(
  UMAP1 = ames_umap[, 1],
  UMAP2 = ames_umap[, 2],
  Sale_Price = ames_train$Sale_Price,
  Neighborhood = ames_train$Neighborhood
)

head(umap_df)
#>       UMAP1     UMAP2 Sale_Price       Neighborhood
#> 1  1.124761 -6.094663     146300    Northpark_Villa
#> 2 -0.192151 -6.755127     213000 Northridge_Heights
#> 3 -4.920448 -1.364412     200000         North_Ames
#> 4 -1.993214  3.161109     139000           Mitchell
#> 5 -5.938463 -2.093811     281500 Northridge_Heights
#> 6  2.287517  0.501158     150000         North_Ames
```

## Visualizing the UMAP Embedding

### Colored by Sale Price

Code

``` r
ggplot(umap_df, aes(UMAP1, UMAP2, color = Sale_Price)) +
  geom_point(alpha = 0.6, size = 1) +
  scale_color_viridis_c(labels = scales::dollar) +
  labs(
    title = "UMAP Projection of Ames Housing Features",
    subtitle = "Colored by Sale Price",
    color = "Sale Price"
  ) +
  theme_minimal() +
  coord_fixed()
```

![](categorical-umap_files/figure-html/umap-viz-price-1.png)

UMAP projection of Ames housing features colored by sale price. Similar
houses (in terms of the 16 numeric features) are positioned near each
other.

The UMAP projection reveals structure in the data—houses with similar
characteristics cluster together, and there’s a gradient of sale prices
across the embedding.

### Colored by Neighborhood

Code

``` r
# Show top 8 neighborhoods for clarity
top_neighborhoods <- ames_train %>%
  count(Neighborhood, sort = TRUE) %>%
  head(8) %>%
  pull(Neighborhood)

umap_df %>%
  filter(Neighborhood %in% top_neighborhoods) %>%
  ggplot(aes(UMAP1, UMAP2, color = Neighborhood)) +
  geom_point(alpha = 0.6, size = 1.5) +
  labs(
    title = "UMAP Projection by Neighborhood",
    subtitle = "Top 8 neighborhoods shown"
  ) +
  theme_minimal() +
  coord_fixed()
```

![](categorical-umap_files/figure-html/umap-viz-neighborhood-1.png)

UMAP projection colored by neighborhood. Some neighborhoods form
distinct clusters while others overlap.

## Key UMAP Parameters

Understanding the main parameters helps tune UMAP for your use case:

| Parameter      | Description                     | Effect                                                    |
|----------------|---------------------------------|-----------------------------------------------------------|
| `n_neighbors`  | Size of local neighborhood      | Higher = more global structure, lower = more local detail |
| `min_dist`     | Minimum distance between points | Higher = more spread out, lower = tighter clusters        |
| `n_components` | Output dimensions               | 2 for visualization, higher for feature creation          |
| `metric`       | Distance measure                | “euclidean”, “cosine”, “manhattan”, etc.                  |

### Effect of n_neighbors

Code

``` r
set.seed(123)

# Compare different n_neighbors values
neighbor_values <- c(5, 15, 50)
umap_results <- lapply(neighbor_values, function(nn) {
  result <- umap(ames_matrix, n_neighbors = nn, n_components = 2,
                 min_dist = 0.1, verbose = FALSE)
  data.frame(
    UMAP1 = result[, 1],
    UMAP2 = result[, 2],
    Sale_Price = ames_train$Sale_Price,
    n_neighbors = paste("n_neighbors =", nn)
  )
})

bind_rows(umap_results) %>%
  ggplot(aes(UMAP1, UMAP2, color = Sale_Price)) +
  geom_point(alpha = 0.5, size = 0.8) +
  scale_color_viridis_c() +
  facet_wrap(~n_neighbors, scales = "free") +
  labs(title = "Effect of n_neighbors on UMAP Structure") +
  theme_minimal()
```

![](categorical-umap_files/figure-html/param-comparison-1.png)

Effect of n_neighbors on UMAP embedding. Lower values emphasize local
structure, higher values capture more global patterns.

## Transforming New Data

A key feature of `uwotmit` is the ability to transform new data using a
fitted UMAP model. This is essential for prediction workflows.

Code

``` r
# Fit UMAP with ret_model = TRUE to enable transformation
set.seed(123)
ames_umap_model <- umap(
  ames_matrix,
  n_neighbors = 15,
  n_components = 2,
  min_dist = 0.1,
  ret_model = TRUE,
  verbose = FALSE
)

# Prepare test data the same way
ames_test_numeric <- ames_test %>%
  select(
    Lot_Area, Gr_Liv_Area, Year_Built, Year_Remod_Add,
    Total_Bsmt_SF, First_Flr_SF, Second_Flr_SF,
    Full_Bath, Half_Bath, Bedroom_AbvGr, TotRms_AbvGrd,
    Fireplaces, Garage_Cars, Garage_Area,
    Wood_Deck_SF, Open_Porch_SF
  ) %>%
  mutate(across(everything(), ~ifelse(is.na(.), median(., na.rm = TRUE), .))) %>%
  mutate(across(everything(), scale))

ames_test_matrix <- as.matrix(ames_test_numeric)

# Transform test data
test_umap <- umap_transform(ames_test_matrix, ames_umap_model)

head(test_umap)
#>            [,1]      [,2]
#> [1,] -0.7904096  4.523987
#> [2,]  2.4070497  5.037006
#> [3,] -5.6313543 -2.111909
#> [4,]  6.3172464 -1.702447
#> [5,]  1.9571251  5.977557
#> [6,]  6.7318058 -1.318505
```

### Visualizing Train and Test Together

Code

``` r
train_df <- data.frame(
  UMAP1 = ames_umap_model$embedding[, 1],
  UMAP2 = ames_umap_model$embedding[, 2],
  Set = "Train"
)

test_df <- data.frame(
  UMAP1 = test_umap[, 1],
  UMAP2 = test_umap[, 2],
  Set = "Test"
)

bind_rows(train_df, test_df) %>%
  ggplot(aes(UMAP1, UMAP2, color = Set)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(
    title = "UMAP: Training vs Test Set Projection",
    subtitle = "Test data transformed using fitted model"
  ) +
  theme_minimal() +
  coord_fixed()
```

![](categorical-umap_files/figure-html/train-test-viz-1.png)

UMAP projection showing both training and test data. Test data is
transformed using the model fitted on training data.

## Using UMAP Components as Features

UMAP components can serve as input features for downstream models:

Code

``` r
# Create UMAP features for modeling
train_features <- data.frame(
  UMAP1 = ames_umap_model$embedding[, 1],
  UMAP2 = ames_umap_model$embedding[, 2],
  Sale_Price = ames_train$Sale_Price
)

# Simple linear model using UMAP features
umap_lm <- lm(Sale_Price ~ UMAP1 + UMAP2, data = train_features)
summary(umap_lm)
#> 
#> Call:
#> lm(formula = Sale_Price ~ UMAP1 + UMAP2, data = train_features)
#> 
#> Residuals:
#>     Min      1Q  Median      3Q     Max 
#> -141031  -34884   -6741   24015  391409 
#> 
#> Coefficients:
#>             Estimate Std. Error t value Pr(>|t|)    
#> (Intercept) 180689.0     1157.6  156.09   <2e-16 ***
#> UMAP1         9948.3      321.2   30.98   <2e-16 ***
#> UMAP2        10435.3      317.0   32.92   <2e-16 ***
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
#> 
#> Residual standard error: 56040 on 2341 degrees of freedom
#> Multiple R-squared:  0.4897, Adjusted R-squared:  0.4893 
#> F-statistic:  1123 on 2 and 2341 DF,  p-value: < 2.2e-16
```

The R-squared tells us how much of the sale price variance is captured
by just two UMAP dimensions.

## Supervised UMAP

`uwotmit` supports *supervised* UMAP, which uses label information to
guide the embedding. This can improve the embedding for prediction
tasks:

Code

``` r
set.seed(123)
ames_supervised <- umap(
  ames_matrix,
  n_neighbors = 15,
  n_components = 2,
  min_dist = 0.1,
  y = ames_train$Sale_Price,
  target_weight = 0.5,
  verbose = FALSE
)

supervised_df <- data.frame(
  UMAP1 = ames_supervised[, 1],
  UMAP2 = ames_supervised[, 2],
  Sale_Price = ames_train$Sale_Price
)

ggplot(supervised_df, aes(UMAP1, UMAP2, color = Sale_Price)) +
  geom_point(alpha = 0.6, size = 1) +
  scale_color_viridis_c(labels = scales::dollar) +
  labs(
    title = "Supervised UMAP Projection",
    subtitle = "Embedding guided by Sale Price"
  ) +
  theme_minimal() +
  coord_fixed()
```

![](categorical-umap_files/figure-html/supervised-umap-1.png)

Supervised UMAP uses the Sale Price outcome to guide the projection,
potentially creating better separation for prediction tasks.

## Integration with embedmit

For a complete workflow combining categorical encoding and UMAP, use
`embedmit` with `step_umap()`:

Code

``` r
library(embedmit)
library(recipes)

# Complete pipeline: encode categoricals, then reduce dimensions
ames_recipe <- recipe(Sale_Price ~ ., data = ames_train) %>%
  # Encode high-cardinality categorical
  step_lencode_mixed(Neighborhood, outcome = vars(Sale_Price)) %>%
  # Create dummy variables for remaining categoricals
  step_dummy(all_nominal_predictors()) %>%
  # Reduce to UMAP components
  step_umap(all_numeric_predictors(), num_comp = 5, neighbors = 15)
```

This pipeline:

1.  Encodes `Neighborhood` using mixed effects (see the embedmit
    vignette)
2.  Creates dummy variables for other categorical predictors
3.  Reduces all numeric features to 5 UMAP components

## Summary

UMAP is a powerful dimensionality reduction technique that complements
categorical encoding:

| Use Case                             | Technique                                                                                                   |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------|
| Encode high-cardinality categoricals | Effect encodings (`step_lencode_*`)                                                                         |
| Visualize high-dimensional data      | UMAP with `n_components = 2`                                                                                |
| Create features from many predictors | UMAP with `n_components > 2`                                                                                |
| Improve embeddings for prediction    | Supervised UMAP with `y` parameter                                                                          |
| Apply to new data                    | [`umap_transform()`](https://rmsharp.github.io/uwotmit/reference/umap_transform.md) with `ret_model = TRUE` |

The `uwotmit` package provides an MIT-licensed UMAP implementation that
integrates seamlessly with `embedmit` for complete feature engineering
workflows.

## References

- McInnes, L., Healy, J., & Melville, J. (2018). UMAP: Uniform Manifold
  Approximation and Projection for Dimension Reduction.
  *arXiv:1802.03426*.
- Kuhn, M., & Silge, J. (2022). *Tidy Modeling with R*. O’Reilly Media.
- [Understanding
  UMAP](https://pair-code.github.io/understanding-umap/) - Interactive
  visualization guide
