//  UWOTMIT -- An R package for dimensionality reduction using UMAP
//  (MIT-compatible fork of uwot)
//
//  Copyright (C) 2018 James Melville
//  Copyright (C) 2025 R. Mark Sharp (MIT-compatible modifications)
//
//  This file is part of UWOTMIT
//
//  UWOTMIT is free software: you can redistribute it and/or modify
//  it under the terms of the MIT License.
//
//  UWOTMIT is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  MIT License for more details.

#ifndef UWOT_RNG_H
#define UWOT_RNG_H

#include <limits>
#include <vector>
#include <cstdint>

// Required for R::runif
#include <Rcpp.h>

// Using sitmo (MIT licensed) instead of dqrng (AGPL)
#include <sitmo.h>

#include "uwot/tauprng.h"

// Custom seed conversion function (replacing dqrng::convert_seed)
// Combines two 32-bit seeds into a single 64-bit seed
inline uint64_t convert_seed(const uint32_t* seeds, std::size_t n) {
  if (n >= 2) {
    return (static_cast<uint64_t>(seeds[1]) << 32) | seeds[0];
  } else if (n == 1) {
    return static_cast<uint64_t>(seeds[0]);
  }
  return 0;
}

// NOT THREAD SAFE
// based on code in the dqsample package
static uint64_t random64() {
  return static_cast<uint64_t>(
      R::runif(0, 1) *
      static_cast<double>((std::numeric_limits<uint64_t>::max)()));
}

// NOT THREAD SAFE
static uint32_t random32() {
  return static_cast<uint32_t>(
      R::runif(0, 1) *
      static_cast<double>((std::numeric_limits<uint32_t>::max)()));
}

struct batch_tau_factory {
  std::size_t n_rngs;
  std::vector<uint64_t> seeds;
  static const constexpr std::size_t seeds_per_rng = 3;

  batch_tau_factory() : n_rngs(1), seeds(seeds_per_rng * n_rngs) {}
  batch_tau_factory(std::size_t n_rngs)
      : n_rngs(n_rngs), seeds(seeds_per_rng * n_rngs) {}

  void reseed() {
    for (std::size_t i = 0; i < seeds.size(); i++) {
      seeds[i] = random64();
    }
  }

  uwot::tau_prng create(std::size_t n) {
    const std::size_t idx = n * seeds_per_rng;
    return uwot::tau_prng(seeds[idx], seeds[idx + 1], seeds[idx + 2]);
  }
};

// PCG PRNG using sitmo (MIT-licensed replacement for dqrng's pcg32)
struct pcg_prng {
  sitmo::prng_engine gen;

  pcg_prng(uint64_t seed) : gen(static_cast<uint32_t>(seed)) {}

  // return a value in (0, n]
  inline std::size_t operator()(std::size_t n, std::size_t, std::size_t) {
    return gen() % n;
  }
};

struct batch_pcg_factory {
  std::size_t n_rngs;
  std::vector<uint32_t> seeds;
  static const constexpr std::size_t seeds_per_rng = 2;

  batch_pcg_factory() : n_rngs(1), seeds(seeds_per_rng * n_rngs) {}
  batch_pcg_factory(std::size_t n_rngs)
      : n_rngs(n_rngs), seeds(seeds_per_rng * n_rngs) {}

  void reseed() {
    for (std::size_t i = 0; i < seeds.size(); i++) {
      seeds[i] = random32();
    }
  }

  pcg_prng create(std::size_t n) {
    uint32_t pcg_seeds[2] = {seeds[n * seeds_per_rng],
                             seeds[n * seeds_per_rng + 1]};
    return pcg_prng(convert_seed(pcg_seeds, 2));
  }
};

// For backwards compatibility in non-batch mode
struct tau_factory {
  uint64_t seed1;
  uint64_t seed2;
  tau_factory(std::size_t) : seed1(0), seed2(0) {
    seed1 = random64();
    seed2 = random64();
  }

  void reseed() {
    seed1 = random64();
    seed2 = random64();
  }

  uwot::tau_prng create(std::size_t seed) {
    return uwot::tau_prng(seed1, seed2, uint64_t{seed});
  }
};

struct pcg_factory {
  uint32_t seed1;
  pcg_factory(std::size_t) : seed1(random32()) {}

  void reseed() { seed1 = random32(); }

  pcg_prng create(std::size_t seed) {
    uint32_t seeds[2] = {seed1, static_cast<uint32_t>(seed)};
    return pcg_prng(convert_seed(seeds, 2));
  }
};

struct deterministic_factory {
  deterministic_factory(std::size_t) {}

  void reseed() {}

  uwot::deterministic_ng create(std::size_t seed) {
    return uwot::deterministic_ng();
  }
};

#endif // UWOT_RNG_H
