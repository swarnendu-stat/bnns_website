---
title: "Small-Data Forecasting with bnns 1.0.0: The Nile in 100 Observations"
author: "Swarnendu Chatterjee"
date: "2026-06-20T00:01:00+0530"
draft: false
slug: bnns-100-small-data-forecasting
categories: ["R", "Bayesian Methods", "Machine Learning"]
tags: ["bnns", "Bayesian Neural Networks", "tidymodels", "Small Data", "Forecasting"]
description: "A compact bnns 1.0.0 example using the 100-observation Nile dataset, showing why regularization and posterior uncertainty are especially useful when data are scarce."
output: hugodown::md_document
---



Neural networks are usually introduced with large datasets. Many real analyses have the opposite problem: only a few dozen annual measurements, a costly experiment, or a rare outcome. In those settings, a flexible model can fit the observations very closely while telling us little about what will happen next.

Bayesian methods are particularly valuable here. Priors regularize the model, posterior draws retain uncertainty about its weights, and posterior predictive intervals make the limits of a small dataset visible. We do not manufacture information that is not present; we express uncertainty about what the available information supports.

This post uses `bnns` 1.0.0 with the [`Nile`](https://stat.ethz.ch/R-manual/R-devel/library/datasets/html/Nile.html) dataset included with R. It contains only 100 observations: annual flow of the Nile at Aswan from 1871 through 1970. Because there is no download and the network is deliberately small, the entire post is much quicker to reproduce than a large hourly-demand example.

## A genuinely small forecasting problem

We predict annual flow from the year and the previous two annual flows. After constructing the lags, only 98 complete observations remain. The first 80% form the training set and the final 20% form a chronological test set.


``` r
library(dplyr)
library(tidymodels)
library(bnns)
library(ggplot2)

nile <- tibble(
  year = as.numeric(time(Nile)),
  flow = as.numeric(Nile)
) |>
  mutate(
    lag_1 = lag(flow, 1),
    lag_2 = lag(flow, 2)
  ) |>
  tidyr::drop_na()

nile
#> # A tibble: 98 × 4
#>     year  flow lag_1 lag_2
#>    <dbl> <dbl> <dbl> <dbl>
#>  1  1873   963  1160  1120
#>  2  1874  1210   963  1160
#>  3  1875  1160  1210   963
#>  4  1876  1160  1160  1210
#>  5  1877   813  1160  1160
#>  6  1878  1230   813  1160
#>  7  1879  1370  1230   813
#>  8  1880  1140  1370  1230
#>  9  1881   995  1140  1370
#> 10  1882   935   995  1140
#> # ℹ 88 more rows
```

This is an intentionally modest information set. A large network would have far more freedom than the data can justify. The goal is not to squeeze every last unit of training error from 78 or so training rows. It is to obtain a useful forecast while acknowledging how much remains unknown.

## Why Bayesian modeling helps when observations are scarce

Three features matter in a small sample:

1. **Regularization through priors.** Weakly informative priors keep network weights from becoming implausibly large merely to chase a handful of observations.
2. **Parameter uncertainty.** Rather than behaving as if one fitted set of weights were certainly correct, posterior draws retain many plausible networks.
3. **Predictive uncertainty.** Posterior predictive intervals combine uncertainty in the fitted relationship with irreducible year-to-year variation.

None of these is magic. If 100 observations do not identify a pattern, a Bayesian model should usually report wide uncertainty rather than false confidence. That is a benefit, not a failure.

## A compact workflow

The time split prevents future observations from leaking into training. Normalization is learned from the training data and stored with the model in a `tidymodels` workflow.


``` r
set.seed(2026)

nile_split <- initial_time_split(nile, prop = 0.8)
nile_train <- training(nile_split)
nile_test <- testing(nile_split)

nile_recipe <-
  recipe(flow ~ year + lag_1 + lag_2, data = nile_train) |>
  step_normalize(all_numeric_predictors())
```

The network uses eight hidden units, giving it enough capacity to learn a richer non-linear relationship among year and the two lagged flows. Its normal priors still shrink weights toward zero, which discourages that added flexibility from producing an unnecessarily jagged response. We run 2,000 iterations per chain, including 1,000 warmup iterations, and use four chains on four cores so that convergence can be assessed across multiple independent trajectories. The first fit uses NUTS, Stan's adaptive default sampler.


``` r
bnn_spec <-
  mlp(
    mode = "regression",
    hidden_units = 8,
    epochs = 2000,
    activation = "tanh"
  ) |>
  set_engine(
    "bnns",
    algorithm = "NUTS",
    chains = 4,
    cores = 4,
    warmup = 1000,
    refresh = 0,
    seed = 2026,
    prior_weights = list(
      dist = "normal",
      params = list(mean = 0, sd = 0.5)
    ),
    prior_bias = list(
      dist = "normal",
      params = list(mean = 0, sd = 0.5)
    ),
    prior_sigma = list(
      dist = "inv_gamma",
      params = list(alpha = 2, beta = 1)
    )
  )

nile_workflow <-
  workflow() |>
  add_recipe(nile_recipe) |>
  add_model(bnn_spec)

nuts_time <- system.time({
  fit_bnn <- fit(nile_workflow, data = nile_train)
})
```

The architecture is still modest by modern neural-network standards, but it is substantially more expressive than the earlier three-unit model. With limited data, the additional capacity needs restraint: the regularizing priors keep extreme weights unlikely, while the longer run gives the sampler more opportunity to explore the larger posterior.

## Forecast distributions, not just point estimates

`bnns` can return posterior predictive draws for every test observation. We summarize those draws with a median and an 80% posterior predictive interval.


``` r
pred_raw <- predict(fit_bnn, new_data = nile_test, type = "raw")

# Depending on the parsnip version, raw engine predictions may be returned
# directly as a matrix or wrapped in a `.pred` list-column.
pred_draws <- if (is.data.frame(pred_raw) && ".pred" %in% names(pred_raw)) {
  pred_raw$.pred[[1]]
} else {
  pred_raw
}

pred_draws <- as.matrix(pred_draws)

forecast <- nile_test |>
  mutate(
    pred_median = apply(pred_draws, 1, median),
    pred_lower = apply(pred_draws, 1, quantile, probs = 0.10),
    pred_upper = apply(pred_draws, 1, quantile, probs = 0.90)
  )

forecast |>
  select(year, flow, pred_median, pred_lower, pred_upper)
#> # A tibble: 20 × 5
#>     year  flow pred_median pred_lower pred_upper
#>    <dbl> <dbl>       <dbl>      <dbl>      <dbl>
#>  1  1951   744      0.0567      -1.29       1.37
#>  2  1952   749      0.0496      -1.31       1.41
#>  3  1953   838      0.0264      -1.35       1.49
#>  4  1954  1050      0.0464      -1.33       1.46
#>  5  1955   918      0.0860      -1.35       1.41
#>  6  1956   986      0.0618      -1.26       1.40
#>  7  1957   797      0.0646      -1.33       1.38
#>  8  1958   923      0.0532      -1.30       1.43
#>  9  1959   975      0.0735      -1.36       1.44
#> 10  1960   815      0.0630      -1.34       1.40
#> 11  1961  1020      0.0524      -1.33       1.44
#> 12  1962   906      0.0863      -1.39       1.45
#> 13  1963   901      0.0599      -1.31       1.44
#> 14  1964  1170      0.0523      -1.36       1.45
#> 15  1965   912      0.0684      -1.42       1.49
#> 16  1966   746      0.0449      -1.36       1.53
#> 17  1967   919      0.0504      -1.39       1.49
#> 18  1968   718      0.0608      -1.43       1.50
#> 19  1969   714      0.0468      -1.42       1.51
#> 20  1970   740      0.0359      -1.45       1.57
```

The interval is the main event. With fewer than 80 training observations, a precise-looking point prediction can be seductive. The posterior predictive interval puts the missing information back into the result.


``` r
ggplot(forecast, aes(x = year)) +
  geom_ribbon(
    aes(ymin = pred_lower, ymax = pred_upper),
    fill = "skyblue",
    alpha = 0.35
  ) +
  geom_line(aes(y = pred_median), color = "navy", linewidth = 0.8) +
  geom_point(aes(y = flow), size = 1.8) +
  labs(
    title = "Nile flow forecasts from a small Bayesian neural network",
    subtitle = "Points are observed flows; the ribbon is an 80% posterior predictive interval",
    x = NULL,
    y = "Annual flow"
  ) +
  theme_minimal()
```

<img src="{{< blogdown/postref >}}index_files/figure-html/forecast-plot-1.png" alt="" width="672" />

We can also inspect empirical coverage on the held-out years. With such a small test set, this is a descriptive check rather than a definitive calibration study.


``` r
forecast |>
  summarise(
    test_years = n(),
    rmse = yardstick::rmse_vec(flow, pred_median),
    interval_coverage = mean(flow >= pred_lower & flow <= pred_upper),
    mean_interval_width = mean(pred_upper - pred_lower)
  )
#> # A tibble: 1 × 4
#>   test_years  rmse interval_coverage mean_interval_width
#>        <int> <dbl>             <dbl>               <dbl>
#> 1         20  885.                 0                2.81
```

## Diagnostics still come first

A Bayesian label does not guarantee a trustworthy fit. Check that the chains mixed adequately, that `Rhat` values are close to 1, and that effective sample sizes are reasonable. Divergences or unstable chains are reasons to revisit the model, priors, or sampling settings.


``` r
fit_bnn_engine <- extract_fit_engine(fit_bnn)
summary(fit_bnn_engine)
#> Call:
#> bnns.default(formula = ..y ~ ., data = data, L = 1L, nodes = ~8, 
#>     act_fn = ~"tanh", out_act_fn = 1L, algorithm = ~"NUTS", iter = ~2000, 
#>     warmup = ~1000, chains = ~4, cores = ~4, seed = ~2026, prior_weights = ~list(dist = "normal", 
#>         params = list(mean = 0, sd = 0.5)), prior_bias = ~list(dist = "normal", 
#>         params = list(mean = 0, sd = 0.5)), prior_sigma = ~list(dist = "inv_gamma", 
#>         params = list(alpha = 2, beta = 1)), refresh = ~0)
#> 
#> Data Summary:
#> Number of observations: 78 
#> Number of features: 4 
#> 
#> Network Architecture:
#> Number of hidden layers: 1 
#> Nodes per layer: 8 
#> Activation functions: 1 
#> Output activation function: 1 
#> 
#> Posterior Summary (Key Parameters):
#>                   mean     se_mean         sd        2.5%         25%
#> w_out[1]  2.710486e-03 0.005444289  0.5011668  -0.9598997  -0.3400081
#> w_out[2]  4.868266e-03 0.005689320  0.4976867  -0.9607705  -0.3439657
#> w_out[3] -1.469647e-03 0.006604719  0.5149862  -1.0023053  -0.3532501
#> w_out[4]  3.245075e-03 0.005365046  0.5015748  -0.9458887  -0.3498741
#> w_out[5] -1.703829e-03 0.005662699  0.4922698  -0.9673156  -0.3255839
#> w_out[6]  6.696797e-04 0.005744919  0.4931042  -0.9621819  -0.3277282
#> w_out[7] -5.943764e-03 0.006383639  0.4865901  -0.9592106  -0.3310366
#> w_out[8]  8.066782e-03 0.005600673  0.4874939  -0.9372709  -0.3127229
#> b_out[1]  2.186273e-02 0.005846504  0.5113372  -0.9935038  -0.3234201
#> sigma     9.363037e+02 0.922936570 74.9188984 803.9786847 882.9968567
#>                    50%         75%        97.5%    n_eff      Rhat
#> w_out[1]  1.069027e-03   0.3454954    0.9861609 8473.878 0.9993319
#> w_out[2] -1.373641e-04   0.3514446    0.9775104 7652.290 0.9993163
#> w_out[3] -1.307828e-03   0.3458885    0.9958171 6079.706 0.9991824
#> w_out[4]  1.036443e-02   0.3472721    0.9769991 8740.263 0.9996456
#> w_out[5] -2.593602e-03   0.3157479    0.9742774 7557.173 0.9996604
#> w_out[6] -4.968050e-04   0.3364999    0.9673024 7367.322 0.9992239
#> w_out[7] -1.057651e-02   0.3234840    0.9669021 5810.185 0.9997441
#> w_out[8]  7.524713e-03   0.3319302    0.9323448 7576.316 0.9993333
#> b_out[1]  2.028665e-02   0.3775983    0.9993081 7649.312 0.9996142
#> sigma     9.317721e+02 983.6498413 1097.0060903 6589.297 0.9992571
#> 
#> Model Fit Information:
#> Iterations: 2000 
#> Warmup: 1000 
#> Thinning: 1 
#> Chains: 4 
#> 
#> Predictive Performance:
#> RMSE (training): 940.9852 
#> MAE (training): 924.4941 
#> 
#> Notes:
#> Check convergence diagnostics for parameters with high R-hat values.
```

The `bnns` plot method makes the sampler diagnostics much easier to inspect. Calling the standard `plot()` generic below dispatches to `plot.bnns()`.


``` r
plot(
  fit_bnn_engine,
  type = "trace",
  pars = c("b_out", "sigma")
)
```

<img src="{{< blogdown/postref >}}index_files/figure-html/bnns-trace-plot-1.png" alt="" width="672" />

Trace plots should look like overlapping, stationary bands rather than chains occupying separate regions. The corresponding density plot provides another view of agreement among chains.


``` r
plot(
  fit_bnn_engine,
  type = "density",
  pars = c("b_out", "sigma")
)
```

<img src="{{< blogdown/postref >}}index_files/figure-html/bnns-density-plot-1.png" alt="" width="672" />

Finally, a posterior predictive check compares replicated outcomes from the fitted model with the observed training outcomes. Large systematic differences suggest that the network or likelihood is missing an important feature of the data.


``` r
plot(fit_bnn_engine, type = "posterior_predictive")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/bnns-ppc-plot-1.png" alt="" width="672" />

## NUTS versus fixed-trajectory HMC

NUTS is itself a form of Hamiltonian Monte Carlo. It automatically adapts the trajectory length during warmup, avoiding the need to choose that important tuning quantity manually. Here, “HMC” refers to Stan's fixed-trajectory HMC option. To make the comparison fair, the second fit uses the same data, architecture, priors, iterations, warmup, and four chains; only the sampling algorithm changes.


``` r
hmc_spec <-
  mlp(
    mode = "regression",
    hidden_units = 8,
    epochs = 2000,
    activation = "tanh"
  ) |>
  set_engine(
    "bnns",
    algorithm = "HMC",
    chains = 4,
    cores = 4,
    warmup = 1000,
    refresh = 0,
    seed = 2027,
    prior_weights = list(
      dist = "normal",
      params = list(mean = 0, sd = 0.5)
    ),
    prior_bias = list(
      dist = "normal",
      params = list(mean = 0, sd = 0.5)
    ),
    prior_sigma = list(
      dist = "inv_gamma",
      params = list(alpha = 2, beta = 1)
    )
  )

hmc_workflow <-
  workflow() |>
  add_recipe(nile_recipe) |>
  add_model(hmc_spec)

hmc_time <- system.time({
  fit_hmc <- fit(hmc_workflow, data = nile_train)
})

fit_hmc_engine <- extract_fit_engine(fit_hmc)
```

We compare held-out accuracy, interval coverage, interval width, and elapsed fitting time. Similar predictive summaries are reassuring: they indicate that the substantive conclusion is not being driven by the sampler choice. Runtime alone should never decide the winner; convergence diagnostics and effective sample sizes matter first.


``` r
summarise_sampler <- function(fitted_workflow, sampler, elapsed) {
  raw <- predict(fitted_workflow, new_data = nile_test, type = "raw")

  draws <- if (is.data.frame(raw) && ".pred" %in% names(raw)) {
    raw$.pred[[1]]
  } else {
    raw
  }

  draws <- as.matrix(draws)
  centre <- apply(draws, 1, median)
  lower <- apply(draws, 1, quantile, probs = 0.10)
  upper <- apply(draws, 1, quantile, probs = 0.90)

  tibble(
    sampler = sampler,
    rmse = yardstick::rmse_vec(nile_test$flow, centre),
    interval_coverage = mean(
      nile_test$flow >= lower & nile_test$flow <= upper
    ),
    mean_interval_width = mean(upper - lower),
    elapsed_seconds = unname(elapsed[["elapsed"]])
  )
}

sampler_comparison <- bind_rows(
  summarise_sampler(fit_bnn, "NUTS", nuts_time),
  summarise_sampler(fit_hmc, "HMC", hmc_time)
)

sampler_comparison
#> # A tibble: 2 × 5
#>   sampler  rmse interval_coverage mean_interval_width elapsed_seconds
#>   <chr>   <dbl>             <dbl>               <dbl>           <dbl>
#> 1 NUTS     885.                 0                2.81            49.9
#> 2 HMC      886.                 0                2.78            14.2
```

The two posterior predictive medians can also be compared year by year. They need not be identical—Monte Carlo sampling introduces variation—but major systematic disagreement would call for closer examination of trace plots, divergences, and effective sample sizes.


``` r
nuts_median <- apply(pred_draws, 1, median)
hmc_raw <- predict(fit_hmc, new_data = nile_test, type = "raw")
hmc_draws <- if (is.data.frame(hmc_raw) && ".pred" %in% names(hmc_raw)) {
  hmc_raw$.pred[[1]]
} else {
  hmc_raw
}
hmc_median <- apply(as.matrix(hmc_draws), 1, median)

tibble(
  year = rep(nile_test$year, 2),
  predicted_flow = c(nuts_median, hmc_median),
  sampler = rep(c("NUTS", "HMC"), each = nrow(nile_test))
) |>
  ggplot(aes(year, predicted_flow, color = sampler)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.5) +
  geom_point(
    data = nile_test,
    aes(year, flow),
    inherit.aes = FALSE,
    color = "grey30",
    shape = 4,
    size = 2
  ) +
  labs(
    title = "Held-out predictions from NUTS and HMC",
    subtitle = "Crosses show observed annual Nile flow",
    x = NULL,
    y = "Posterior median flow",
    color = NULL
  ) +
  theme_minimal()
```

<img src="{{< blogdown/postref >}}index_files/figure-html/compare-sampler-plot-1.png" alt="" width="672" />

LOO and WAIC are useful for comparing Bayesian models, but they add work and are therefore left unevaluated during rendering.


``` r
loo.bnns(fit_bnn_engine)
waic.bnns(fit_bnn_engine)
```

## What the small dataset changes

With thousands of observations, a flexible predictor may be able to learn complex interactions directly. With 100 observations, the priorities shift:

1. Use a compact architecture rather than searching a large grid of networks.
2. Choose priors that encode reasonable scales and discourage extreme weights.
3. Preserve chronological separation between training and testing.
4. Report posterior predictive intervals alongside point summaries.
5. Treat model diagnostics and sensitivity to priors as part of the result.

This is where Bayesian neural networks are most intellectually honest. They allow non-linearity, but they do not require us to pretend that a small sample determines one exact curve.

## Saving the fitted workflow

The fitted preprocessing and model can be saved together, so the HMC fit need not be repeated merely to revisit a plot.


``` r
saveRDS(fit_bnn, "nile_small_data_bnn.rds")
fit_bnn <- readRDS("nile_small_data_bnn.rds")
```

## Closing thought

Small datasets are not an edge case. They arise whenever measurements are expensive, events are rare, or the scientifically relevant time scale is long. In those settings, uncertainty is not decorative output attached to a forecast; it is part of the forecast.

The 100-observation Nile series makes the point cleanly. A small `bnns` model can describe a flexible relationship, priors can prevent that flexibility from running wild, and posterior predictions can show how much the data do—and do not—tell us. That calibrated humility is one of the strongest reasons to use Bayesian methods when data are scarce.
