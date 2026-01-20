# Changelog

## uwotmit 1.0.0

### Initial Release

This is the first release of uwotmit, an MIT-licensed fork of the uwot
package (version 0.2.4) by James Melville.

#### Key Differences from uwot

- **MIT License**: uwotmit is fully MIT-licensed, replacing the
  AGPL-licensed dqrng dependency with the MIT-licensed sitmo package for
  the PCG random number generator. This makes uwotmit suitable for
  inclusion in projects requiring permissive licensing.

- **Package renamed**: The package is named `uwotmit` to distinguish it
  from the original `uwot` package and to indicate its MIT licensing.

#### Inherited Features from uwot 0.2.4

uwotmit inherits all features from uwot 0.2.4, including:

- UMAP (Uniform Manifold Approximation and Projection) dimensionality
  reduction
- LargeVis method for dimensionality reduction
- Supervised and semi-supervised dimension reduction
- Multiple nearest neighbor methods: Annoy, HNSW, and nearest neighbor
  descent
- Model saving/loading for transforming new data
- Multiple distance metrics: Euclidean, cosine, Manhattan, Hamming,
  correlation
- Mixed data type support
- Batch mode for reproducible multi-threaded results
- Density-preserving UMAP (densMAP approximation)

#### Acknowledgments

This package is based on uwot by James Melville. All credit for the UMAP
implementation goes to the original author. This fork exists solely to
provide an MIT-licensed alternative for users who require permissive
licensing.

For the original uwot package, see: <https://github.com/jlmelville/uwot>
