---
title: "bnns 1.0.0 with tidymodels: Wisconsin Breast Cancer in 100 Observations"
author: "Swarnendu Chatterjee"
date: "2026-06-20T00:01:00+0530"
draft: false
slug: bnns-100-wisconsin-breast-cancer
categories: ["R", "Bayesian Methods", "Machine Learning"]
tags: ["bnns", "Bayesian Neural Networks", "Small Data", "Classification", "Breast Cancer"]
description: "A small-data classification example highlighting the new tidymodels integration, prediction methods, diagnostics, and model utilities in bnns 1.0.0."
output: hugodown::md_document
---



Neural networks are usually introduced with large datasets. Many real analyses have the opposite problem: observations may be expensive, outcomes may be rare, or only a small pilot study may be available. In those settings, a flexible classifier can fit the training cases closely while being much less certain about new ones.

Bayesian methods are particularly valuable here. Priors regularize the model, posterior draws retain uncertainty about its weights, and intervals around predicted probabilities make the limits of a small dataset visible. We do not manufacture information that is not present; we express uncertainty about what the available information supports.

This post uses a stratified 100-case sample from the Wisconsin Breast Cancer dataset to highlight what is new in `bnns` 1.0.0. Most importantly, `bnns` is now a fully registered `parsnip` engine. Bayesian neural networks can be specified with `mlp()`, combined with `recipes` and `workflows`, evaluated with `yardstick`, and tuned with the broader tidymodels ecosystem.

Version 1.0.0 also adds `plot.bnns()` diagnostics, LOO and WAIC model assessment, dedicated save/load helpers, character activation names, and optional GPU acceleration through OpenCL and `cmdstanr`. The example below keeps the model deliberately compact while demonstrating the features that fit naturally into one reproducible workflow.

This is an educational demonstration, not a clinical decision tool. The data describe digitized characteristics of fine-needle aspirates, and a real diagnostic workflow requires external validation, careful calibration, and clinical oversight.

## A genuinely small classification problem

The `BreastCancer` data in the `mlbench` package contain 699 cases before incomplete rows are removed. Nine ordinal cytology measurements take values from 1 to 10, and the outcome records whether the tumor was benign or malignant. We remove the sample identifier, discard rows with missing measurements, convert the predictors to numeric values, and encode malignancy as 1.

To preserve the small-data theme, we draw 100 cases with roughly the same class balance as the complete dataset: 65 benign and 35 malignant observations. This deliberate restriction mimics an early-stage study in which only a modest labeled sample is available.


``` r
library(bnns)
library(mlbench)
library(tidymodels)

data("BreastCancer", package = "mlbench")

breast_cancer_all <- BreastCancer |>
  select(-Id) |>
  tidyr::drop_na() |>
  mutate(
    across(-Class, ~ as.numeric(as.character(.x))),
    diagnosis = factor(Class, levels = c("malignant", "benign"))
  ) |>
  select(-Class)

set.seed(2026)

breast_cancer <- bind_rows(
  breast_cancer_all |>
    filter(diagnosis == "benign") |>
    slice_sample(n = 65),
  breast_cancer_all |>
    filter(diagnosis == "malignant") |>
    slice_sample(n = 35)
) |>
  slice_sample(prop = 1)

breast_cancer |>
  summarise(
    cases = n(),
    malignant = sum(diagnosis == "malignant"),
    benign = sum(diagnosis == "benign")
  )
#>   cases malignant benign
#> 1   100        35     65
```

Only about 80 cases will be available for training. A large network would therefore have far more freedom than the data can justify. The class distribution is also uneven, so the train/test split is stratified to preserve approximately the same malignant proportion in both sets.


``` r
set.seed(2026)

cancer_split <- initial_split(
  breast_cancer,
  prop = 0.8,
  strata = diagnosis
)
cancer_train <- training(cancer_split)
cancer_test <- testing(cancer_split)

bind_rows(
  summarise(cancer_train, set = "Training", n = n(), malignant_rate = mean(diagnosis == "malignant")),
  summarise(cancer_test, set = "Test", n = n(), malignant_rate = mean(diagnosis == "malignant"))
)
#>        set  n malignant_rate
#> 1 Training 80           0.35
#> 2     Test 20           0.35
```

## Why Bayesian modeling helps when observations are scarce

Three features matter in this small sample:

1. **Regularization through priors.** Weakly informative priors keep network weights from becoming implausibly large merely to classify a handful of observations.
2. **Parameter uncertainty.** Posterior draws retain many plausible networks instead of treating one fitted set of weights as certainly correct.
3. **Predictive uncertainty.** Intervals around malignancy probabilities reveal cases for which plausible networks disagree.

None of these is magic. If 100 observations do not identify a pattern, a Bayesian model should express that limitation rather than produce false confidence.

## The new tidymodels engine

The central addition in `bnns` 1.0.0 is its native tidymodels integration. Loading `bnns` registers `"bnns"` as an engine for `parsnip::mlp()`. The familiar parsnip arguments map to Bayesian neural-network settings: `hidden_units` controls the nodes, `epochs` controls the total Stan iterations, and `activation` sets the hidden-layer activation function.

The recipe learns normalization values from the training data and stores them inside the fitted workflow. This replaces the manual preprocessing code that would otherwise have to be kept in sync with the fitted model.


``` r
cancer_recipe <-
  recipe(diagnosis ~ ., data = cancer_train) |>
  step_normalize(all_numeric_predictors())
```

The model has one hidden layer with eight nodes and uses the newly supported character activation name `"relu"`. Because the outcome is a two-level factor and the mode is classification, the engine automatically uses the appropriate binary output activation. Normal priors shrink weights and biases toward zero, restraining a flexible network fitted to only about 80 training cases.


``` r
bnn_spec <-
  mlp(
    mode = "classification",
    hidden_units = 8,
    epochs = 2000,
    activation = "relu"
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
    )
  )
```

The recipe and model specification become one workflow. From this point onward, preprocessing and fitting travel together.


``` r
cancer_workflow <-
  workflow() |>
  add_recipe(cancer_recipe) |>
  add_model(bnn_spec)

fit_bnn <- fit(cancer_workflow, data = cancer_train)
```

## Standard tidymodels predictions

The new engine supports standard parsnip prediction types. Class predictions return a `.pred_class` column, while probability predictions return one column per outcome level. These results can be passed directly to `yardstick`.


``` r
class_predictions <- predict(
  fit_bnn,
  new_data = cancer_test,
  type = "class"
)

probability_predictions <- predict(
  fit_bnn,
  new_data = cancer_test,
  type = "prob"
)

predictions <- bind_cols(
  cancer_test |> select(diagnosis),
  class_predictions,
  probability_predictions
)

predictions
#>     diagnosis .pred_class .pred_malignant .pred_benign
#> 381    benign      benign      0.01742681   0.98257319
#> 528    benign      benign      0.03384616   0.96615384
#> 55  malignant   malignant      0.90882191   0.09117809
#> 563    benign      benign      0.02269826   0.97730174
#> 341 malignant   malignant      0.85197508   0.14802492
#> 590    benign      benign      0.03213257   0.96786743
#> 668    benign      benign      0.02865862   0.97134138
#> 6   malignant   malignant      0.98902098   0.01097902
#> 247 malignant   malignant      0.98777402   0.01222598
#> 579    benign      benign      0.01950734   0.98049266
#> 102 malignant      benign      0.36800429   0.63199571
#> 665    benign      benign      0.03473679   0.96526321
#> 425    benign      benign      0.02213016   0.97786984
#> 183    benign      benign      0.05246825   0.94753175
#> 249    benign      benign      0.09874160   0.90125840
#> 72  malignant   malignant      0.85861506   0.14138494
#> 516 malignant   malignant      0.94863974   0.05136026
#> 344    benign      benign      0.01742681   0.98257319
#> 197    benign   malignant      0.91789219   0.08210781
#> 14     benign      benign      0.03413819   0.96586181
```

## Recovering posterior uncertainty

The parsnip probability prediction is the posterior mean and is ideal for standard metrics. For the distinctly Bayesian part of the analysis, we extract the fitted `bnns` engine from the workflow and retain all posterior probability draws. We use a prepared copy of the same recipe so that these engine-level predictions receive exactly the preprocessing specified by the workflow.


``` r
fit_bnn_engine <- extract_fit_engine(fit_bnn)

prepared_recipe <- prep(cancer_recipe, training = cancer_train)
cancer_test_baked <- bake(
  prepared_recipe,
  new_data = cancer_test
) |>
  select(-diagnosis)

probability_draws <- predict(
  fit_bnn_engine,
  newdata = cancer_test_baked
)

# The raw binary draws represent the second factor level (benign).
# Malignant is the first level, matching yardstick's event convention.
malignant_draws <- 1 - probability_draws

predictions <- predictions |>
  mutate(
    posterior_median = apply(malignant_draws, 1, median),
    lower = apply(malignant_draws, 1, quantile, probs = 0.10),
    upper = apply(malignant_draws, 1, quantile, probs = 0.90),
    uncertainty = upper - lower
  )

predictions |>
  arrange(desc(uncertainty)) |>
  slice_head(n = 10)
#>     diagnosis .pred_class .pred_malignant .pred_benign posterior_median
#> 102 malignant      benign      0.36800429   0.63199571       0.34787947
#> 72  malignant   malignant      0.85861506   0.14138494       0.95757404
#> 341 malignant   malignant      0.85197508   0.14802492       0.91003852
#> 55  malignant   malignant      0.90882191   0.09117809       0.94572235
#> 249    benign      benign      0.09874160   0.90125840       0.06793513
#> 197    benign   malignant      0.91789219   0.08210781       0.94413702
#> 516 malignant   malignant      0.94863974   0.05136026       0.98356243
#> 183    benign      benign      0.05246825   0.94753175       0.04050935
#> 14     benign      benign      0.03413819   0.96586181       0.02382586
#> 665    benign      benign      0.03473679   0.96526321       0.02649521
#>           lower      upper uncertainty
#> 102 0.124741920 0.64421534  0.51947342
#> 72  0.550706300 0.99917403  0.44846773
#> 341 0.626825133 0.99096914  0.36414401
#> 55  0.771190591 0.99286018  0.22166958
#> 249 0.014310794 0.22595297  0.21164218
#> 197 0.810634126 0.99022943  0.17959531
#> 516 0.854550930 0.99906252  0.14451159
#> 183 0.009927198 0.11089559  0.10096839
#> 14  0.004647709 0.07666086  0.07201315
#> 665 0.006710708 0.07400600  0.06729530
```

The widest intervals identify cases for which plausible networks disagree most. These are often more informative than the easiest correctly classified cases.


``` r
predictions |>
  arrange(posterior_median) |>
  mutate(case = row_number()) |>
  ggplot(aes(case, posterior_median, color = diagnosis)) +
  geom_linerange(aes(ymin = lower, ymax = upper), alpha = 0.55) +
  geom_point(size = 1.4) +
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  scale_color_manual(values = c(malignant = "#B2182B", benign = "#2166AC")) +
  labs(
    title = "Posterior malignancy probabilities",
    subtitle = "Points are medians; vertical lines are 80% credible intervals",
    x = "Held-out cases, ordered by predicted probability",
    y = "Probability of malignancy",
    color = "Observed class"
  ) +
  theme_minimal()
```

<img src="{{< blogdown/postref >}}index_files/figure-html/uncertainty-plot-1.png" alt="" width="672" />

## Held-out classification performance

Threshold-free ROC AUC summarizes ranking performance. Sensitivity and specificity use a 0.5 decision threshold. In a clinical application, that threshold should reflect the relative consequences of missed malignancies and unnecessary follow-up rather than being accepted automatically.


``` r
metric_set(roc_auc, accuracy, sens, spec)(
  predictions,
  truth = diagnosis,
  estimate = .pred_class,
  .pred_malignant,
  event_level = "first"
)
#> # A tibble: 4 × 3
#>   .metric  .estimator .estimate
#>   <chr>    <chr>          <dbl>
#> 1 accuracy binary         0.9  
#> 2 sens     binary         0.857
#> 3 spec     binary         0.923
#> 4 roc_auc  binary         0.956
```

A confusion matrix makes the errors concrete.


``` r
conf_mat(predictions, truth = diagnosis, estimate = .pred_class)
#>            Truth
#> Prediction  malignant benign
#>   malignant         6      1
#>   benign            1     12
```

We can also inspect the ROC curve without committing to one threshold.


``` r
predictions |>
  roc_curve(diagnosis, .pred_malignant, event_level = "first") |>
  autoplot() +
  coord_equal() +
  labs(title = "Held-out ROC curve") +
  theme_minimal()
```

<img src="{{< blogdown/postref >}}index_files/figure-html/roc-plot-1.png" alt="" width="672" />

## Diagnostics still come first

Good predictive scores do not prove that the posterior computation is reliable. `Rhat` values should be close to 1, effective sample sizes should be adequate, and chains should mix without persistent separation. Divergences are a reason to revisit the architecture, priors, or sampler settings.


``` r
summary(fit_bnn_engine)
#> Call:
#> bnns.default(formula = ..y ~ ., data = data, L = 1L, nodes = ~8, 
#>     act_fn = ~"relu", algorithm = ~"NUTS", iter = ~2000, warmup = ~1000, 
#>     chains = ~4, cores = ~4, seed = ~2026, prior_weights = ~list(dist = "normal", 
#>         params = list(mean = 0, sd = 0.5)), prior_bias = ~list(dist = "normal", 
#>         params = list(mean = 0, sd = 0.5)), refresh = ~0)
#> 
#> Data Summary:
#> Number of observations: 80 
#> Number of features: 10 
#> 
#> Network Architecture:
#> Number of hidden layers: 1 
#> Nodes per layer: 8 
#> Activation functions: 4 
#> Output activation function: 2 
#> 
#> Posterior Summary (Key Parameters):
#>                 mean     se_mean        sd       2.5%         25%          50%
#> w_out[1] 0.028844860 0.019191434 0.6991684 -1.2424880 -0.51268616  0.015508952
#> w_out[2] 0.058431359 0.018337014 0.6964167 -1.1879923 -0.45974240  0.039753657
#> w_out[3] 0.006523585 0.016797527 0.6907952 -1.2549198 -0.51024479 -0.023465156
#> w_out[4] 0.014178503 0.017017933 0.6772062 -1.1821364 -0.48136029 -0.008610242
#> w_out[5] 0.015720911 0.017845036 0.6877341 -1.2564939 -0.48277253 -0.025188606
#> w_out[6] 0.032982679 0.018024245 0.6819240 -1.2060555 -0.47120944 -0.007720606
#> w_out[7] 0.034698134 0.018348716 0.6975313 -1.2144981 -0.49327675  0.007603325
#> w_out[8] 0.080964090 0.019716039 0.7095801 -1.2222687 -0.45825968  0.062261822
#> b_out[1] 0.220139464 0.007494657 0.4764362 -0.7455428 -0.08967655  0.224026274
#>                75%    97.5%    n_eff     Rhat
#> w_out[1] 0.5387738 1.355115 1327.238 1.000629
#> w_out[2] 0.5695861 1.376773 1442.385 1.005517
#> w_out[3] 0.5057600 1.318353 1691.250 1.000217
#> w_out[4] 0.4843138 1.333012 1583.537 1.001160
#> w_out[5] 0.4879317 1.386777 1485.273 1.000589
#> w_out[6] 0.5181018 1.367569 1431.389 1.001106
#> w_out[7] 0.5455285 1.374319 1445.160 1.000757
#> w_out[8] 0.6058601 1.425332 1295.280 1.000624
#> b_out[1] 0.5332228 1.147598 4041.159 1.000727
#> 
#> Model Fit Information:
#> Iterations: 2000 
#> Warmup: 1000 
#> Thinning: 1 
#> Chains: 4 
#> 
#> Predictive Performance:
#> Confusion matrix (training with 0.5 cutoff): 28 1 0 51 
#> Accuracy (training with 0.5 cutoff): 0.9875 
#> AUC (training): 0.9986264 
#> 
#> Notes:
#> Check convergence diagnostics for parameters with high R-hat values.
```

Trace and density plots provide complementary views of chain behavior.


``` r
plot(fit_bnn_engine, type = "trace", pars = "b_out")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/trace-plot-1.png" alt="" width="672" />


``` r
plot(fit_bnn_engine, type = "density", pars = "b_out")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/density-plot-1.png" alt="" width="672" />

A posterior predictive check asks whether outcomes replicated from the fitted model resemble the observed training outcomes.


``` r
plot(fit_bnn_engine, type = "posterior_predictive")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/posterior-predictive-check-1.png" alt="" width="672" />

## Leave-one-out evaluation in version 1.0.0

`bnns` 1.0.0 adds a method for Pareto-smoothed importance-sampling leave-one-out cross-validation (PSIS-LOO). Calling the exported `loo::loo()` generic dispatches automatically to the package's `bnns` method. It estimates how well the fitted model predicts each training observation when that observation is treated as left out, without refitting the network 80 separate times.


``` r
loo_result <- loo::loo(fit_bnn_engine)
loo_result
#> 
#> Computed from 4000 by 80 log-likelihood matrix.
#> 
#>          Estimate  SE
#> elpd_loo     -8.2 1.8
#> p_loo         1.6 0.5
#> looic        16.4 3.5
#> ------
#> MCSE of elpd_loo is 0.0.
#> MCSE and ESS estimates assume MCMC draws (r_eff in [0.8, 1.1]).
#> 
#> All Pareto k estimates are good (k < 0.7).
#> See help('pareto-k-diagnostic') for details.
```

The printed result reports three useful summaries:

1. **`elpd_loo`** is the expected log predictive density. Larger values indicate better expected out-of-sample prediction when models are compared on the same observations.
2. **`p_loo`** estimates the model's effective number of parameters.
3. **`looic`** is `-2 * elpd_loo`, so smaller values are preferred.

The absolute values are less informative than differences between candidate models. The standard errors show whether an apparent difference is large relative to its uncertainty.

### Pareto-k diagnostics

PSIS-LOO also produces a Pareto-$k$ diagnostic for every observation. Values below 0.5 are ideal, values between 0.5 and 0.7 deserve attention, values above 0.7 indicate that the approximation may be unreliable, and values above 1 are especially problematic.


``` r
loo_diagnostics <-
  as_tibble(loo_result$pointwise) |>
  mutate(
    observation = row_number(),
    pareto_k = loo_result$diagnostics$pareto_k,
    reliability = cut(
      pareto_k,
      breaks = c(-Inf, 0.5, 0.7, 1, Inf),
      labels = c("Good", "Okay", "Bad", "Very bad")
    )
  )

loo_diagnostics |>
  count(reliability, .drop = FALSE)
#> # A tibble: 4 × 2
#>   reliability     n
#>   <fct>       <int>
#> 1 Good           77
#> 2 Okay            3
#> 3 Bad             0
#> 4 Very bad        0
```


``` r
ggplot(
  loo_diagnostics,
  aes(observation, pareto_k, color = reliability)
) +
  geom_hline(
    yintercept = c(0.5, 0.7, 1),
    linetype = c("dotted", "dashed", "solid"),
    color = "grey60"
  ) +
  geom_point(size = 2) +
  scale_color_manual(
    values = c(
      "Good" = "#2166AC",
      "Okay" = "#FDAE61",
      "Bad" = "#D73027",
      "Very bad" = "#7F0000"
    ),
    drop = FALSE
  ) +
  labs(
    title = "PSIS-LOO influence diagnostics",
    subtitle = "Large Pareto-k values identify influential training cases",
    x = "Training observation",
    y = "Pareto k",
    color = "Reliability"
  ) +
  theme_minimal()
```

<img src="{{< blogdown/postref >}}index_files/figure-html/pareto-k-plot-1.png" alt="" width="672" />

The plot matters more than a single pass/fail rule. A few high values can reveal unusual tumors that strongly influence the fitted network. If any values exceed 0.7, inspect those cases and consider exact leave-one-out refitting, stronger priors, or a simpler architecture before trusting the approximate LOO result.

### Which observations are hardest to predict?

The pointwise `elpd_loo` contributions show where the model predicts poorly under leave-one-out evaluation. More negative values indicate observations assigned lower predictive probability. The following plot displays the 15 weakest contributions and colors them by their Pareto-$k$ reliability.


``` r
loo_diagnostics |>
  slice_min(elpd_loo, n = 15) |>
  mutate(
    observation = reorder(factor(observation), elpd_loo)
  ) |>
  ggplot(aes(elpd_loo, observation, color = reliability)) +
  geom_segment(
    aes(x = 0, xend = elpd_loo, yend = observation),
    linewidth = 0.7
  ) +
  geom_point(size = 2.5) +
  scale_color_manual(
    values = c(
      "Good" = "#2166AC",
      "Okay" = "#FDAE61",
      "Bad" = "#D73027",
      "Very bad" = "#7F0000"
    ),
    drop = FALSE
  ) +
  labs(
    title = "Weakest leave-one-out predictions",
    subtitle = "More negative pointwise ELPD indicates lower predictive accuracy",
    x = "Pointwise ELPD-LOO",
    y = "Training observation",
    color = "Reliability"
  ) +
  theme_minimal()
```

<img src="{{< blogdown/postref >}}index_files/figure-html/pointwise-elpd-plot-1.png" alt="" width="672" />

WAIC is available through the corresponding `loo::waic()` generic. It is included for comparison, although PSIS-LOO is generally more informative because its Pareto-$k$ values directly diagnose influential observations.


``` r
waic_result <- loo::waic(fit_bnn_engine)
waic_result
#> 
#> Computed from 4000 by 80 log-likelihood matrix.
#> 
#>           Estimate  SE
#> elpd_waic     -8.2 1.7
#> p_waic         1.5 0.5
#> waic          16.3 3.5
```

## Tuning through tidymodels

Because `bnns` is a registered `mlp()` engine, model arguments can use the usual `tune()` placeholders. The example below defines a search over hidden units and activation functions. A real Bayesian tuning run can be expensive because every candidate and resample requires posterior sampling, so the code is illustrative rather than evaluated during rendering.


``` r
tunable_spec <-
  mlp(
    mode = "classification",
    hidden_units = tune(),
    epochs = 2000,
    activation = tune()
  ) |>
  set_engine(
    "bnns",
    chains = 4,
    cores = 4,
    warmup = 1000,
    refresh = 0
  )

tunable_workflow <-
  cancer_workflow |>
  update_model(tunable_spec)
```

## What the small dataset changes

With thousands of observations, a flexible predictor may learn complex interactions directly. With 100 observations, the priorities shift:

1. Use a compact architecture rather than searching a large grid of networks.
2. Choose priors that discourage extreme weights.
3. Keep test cases completely separate from preprocessing and fitting.
4. Report posterior intervals alongside central probability estimates.
5. Treat sampler diagnostics and sensitivity checks as part of the result.

Posterior uncertainty also separates three questions that are easy to collapse into one:

1. **Which class is predicted?** The 0.5 threshold supplies a binary decision.
2. **How high is the estimated risk?** The posterior median supplies a central probability estimate.
3. **How stable is that estimate?** The posterior interval shows how much the prediction changes across plausible network weights.

An interval that crosses 0.5 is especially useful to flag. It indicates that posterior uncertainty alone is sufficient to change the assigned class. A narrow interval far from 0.5 describes a much more stable prediction, although it does not protect against dataset shift or model misspecification.

## Saving the fitted model

Version 1.0.0 introduces `save_bnns()` and `load_bnns()` for fitted engine objects. When the preprocessing recipe must travel with the model, save the complete fitted workflow as well.


``` r
save_bnns(fit_bnn_engine, "wisconsin_breast_cancer_bnns.rds")
restored_engine <- load_bnns("wisconsin_breast_cancer_bnns.rds")

saveRDS(fit_bnn, "wisconsin_breast_cancer_workflow.rds")
restored_workflow <- readRDS("wisconsin_breast_cancer_workflow.rds")
```

## Closing thought

Small datasets are not an edge case. They arise whenever measurements are expensive, outcomes are rare, or a study is still at an early stage. In those settings, uncertainty is not decorative output attached to a classification; it is part of the classification.

The 100-case Wisconsin sample makes the point cleanly. A compact Bayesian neural network can be expressed entirely through `mlp()`, a recipe can protect the preprocessing boundary, and a workflow can carry both into fitting and prediction. Standard tidymodels outputs support familiar performance metrics, while the extracted engine retains posterior draws and the new `bnns` diagnostics.

That combination is the main advance in `bnns` 1.0.0: Bayesian neural-network inference no longer requires giving up the consistent modeling grammar of tidymodels.

That uncertainty is not a substitute for external validation or clinical judgment. It is a clearer account of what this model, trained on these data, actually knows.
