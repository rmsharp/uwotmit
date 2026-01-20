# uwotmit

## MIT-Compatible Fork of uwot

`uwotmit` is an MIT-licensed fork of the
[uwot](https://github.com/jlmelville/uwot) package. It provides the same
UMAP (Uniform Manifold Approximation and Projection) dimensionality
reduction functionality but with MIT-compatible dependencies.

### Why uwotmit?

The original `uwot` package depends on `dqrng` for its PCG random number
generator, which is licensed under AGPL-3. This can create licensing
complications for projects that need to maintain MIT or other permissive
licensing throughout their dependency tree.

`uwotmit` replaces the AGPL-licensed `dqrng` dependency with the
MIT-licensed `sitmo` package, providing the same high-quality random
number generation without the AGPL licensing requirement.

### Key Differences from uwot

| Feature       | uwot           | uwotmit     |
|---------------|----------------|-------------|
| License       | GPL (\>= 3)    | MIT         |
| RNG Library   | dqrng (AGPL-3) | sitmo (MIT) |
| Functionality | Full UMAP      | Full UMAP   |

## Installing

### From GitHub

``` r
# install.packages("devtools")
devtools::install_github("rmsharp/uwotmit")
```

## Example

``` r
library(uwotmit)

# umap2 is a version of the umap() function with better defaults
iris_umap <- umap2(iris)

# but you can still use the umap function
iris_umap <- umap(iris)

# Load mnist from somewhere, e.g.
# devtools::install_github("jlmelville/snedata")
# mnist <- snedata::download_mnist()

mnist_umap <- umap(mnist, n_neighbors = 15, min_dist = 0.001, verbose = TRUE)
plot(
  mnist_umap,
  cex = 0.1,
  col = grDevices::rainbow(n = length(levels(mnist$Label)))[as.integer(mnist$Label)] |>
    grDevices::adjustcolor(alpha.f = 0.1),
  main = "uwotmit::umap",
  xlab = "",
  ylab = ""
)

# Optional packages for faster nearest neighbor search:
install.packages(c("RcppHNSW", "rnndescent"))
library(RcppHNSW)
library(rnndescent)

# HNSW method:
mnist_umap_hnsw <- umap(mnist, n_neighbors = 15, min_dist = 0.001,
                        nn_method = "hnsw")

# nndescent is also available
mnist_umap_nnd <- umap(mnist, n_neighbors = 15, min_dist = 0.001,
                       nn_method = "nndescent")

# umap2 will choose HNSW by default if available
mnist_umap2 <- umap2(mnist)
```

## Documentation

For detailed documentation on UMAP parameters and usage, please refer to
the original uwot documentation at <https://jlmelville.github.io/uwot/>.

## License

[MIT](https://rmsharp.github.io/uwotmit/LICENSE.md)

## Acknowledgments

This package is a fork of [uwot](https://github.com/jlmelville/uwot) by
James Melville. All credit for the core UMAP implementation goes to the
original author and contributors.

## See Also

- The original [uwot package](https://github.com/jlmelville/uwot)
- The [UMAP reference implementation](https://github.com/lmcinnes/umap)
  and [publication](https://arxiv.org/abs/1802.03426)
- [embedmit](https://github.com/rmsharp/embedmit) - MIT-compatible fork
  of the embed package that uses uwotmit
