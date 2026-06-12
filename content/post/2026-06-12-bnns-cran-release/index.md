---
title: "bnns 1.0.0 is now on CRAN"
author: "Swarnendu Chatterjee"
date: "2026-06-12T09:00:00+0530"
slug: bnns-cran-release
categories: ["R", "Bayesian Methods", "Machine Learning"]
tags: ["bnns", "CRAN", "R", "Bayesian Neural Networks", "Stan"]
description: "Announcing the CRAN release of bnns 1.0.0, an R package for Bayesian neural networks powered by Stan."
---

I am happy to share that `bnns` version `1.0.0` is now available on CRAN:

[https://cran.r-project.org/web/packages/bnns/index.html](https://cran.r-project.org/web/packages/bnns/index.html)

CRAN lists the package publication date as June 7, 2026.

You can install it directly from CRAN:

``` r
install.packages("bnns")
```

## What is `bnns`?

`bnns` is an R package for building Bayesian neural networks with a familiar formula interface. Under the hood, it uses `Stan`, so the model output is not just a point prediction: it carries posterior uncertainty with it.

That makes it useful when we care about both prediction and uncertainty quantification, especially in settings where decisions should not be based on a single fitted value alone.

## What the CRAN release includes

The `1.0.0` release supports:

1. Formula-based model specification for Bayesian neural networks.
2. User-chosen priors for weights and biases.
3. Regression, binary classification, and multi-class classification workflows.
4. Posterior predictive summaries that make uncertainty easier to inspect.
5. A workflow designed for applied problems in clinical trials, finance, and other decision-heavy domains.

## A small example

The basic workflow is intentionally close to standard R modeling:

``` r
library(bnns)

fit <- bnns(
  y ~ .,
  data = training_data,
  L = 2,
  nodes = c(16, 8),
  act_fn = c(4, 1),
  iter = 2000,
  warmup = 1000,
  chains = 4
)

pred <- predict(fit, newdata = test_data)
```

From there, predictions can be summarized using posterior medians, credible intervals, or any other posterior quantity that is useful for the analysis.

## Why this matters

Neural networks are often treated as black-box prediction engines. Bayesian neural networks give us a richer object: a model that can learn non-linear relationships while still expressing uncertainty about its predictions.

That is the main motivation behind `bnns`: to make Bayesian neural networks more accessible to R users who want flexible modeling without giving up probabilistic interpretation.

## Links

- CRAN: [bnns on CRAN](https://cran.r-project.org/web/packages/bnns/index.html)
- Package page: [swarnendu-stat.github.io/bnns](https://swarnendu-stat.github.io/bnns/)
- Source code: [github.com/swarnendu-stat/bnns](https://github.com/swarnendu-stat/bnns)

If you try it on your own data, I would be glad to hear what you build with it.
