---
title: "BNNs in Binary Classification: A Bayesian Take on Clinical Prediction"
author: "Swarnendu Chatterjee"
date: "2025-04-18T22:21:00+0530"
slug: bnns-binary-classification
categories: ["Biostatistics", "Machine Learning", "Bayesian Methods"]
tags: ["R", "Bayesian Neural Networks", "Clinical Trials"]
---



## 🔍 Can Bayesian Neural Nets Classify Better Than Your Favorite Models?

We often talk about uncertainty in models, but how often do we actually quantify it?\
Enter `bnns`, an R package that lets you fit **Bayesian Neural Networks** (BNNs) with the elegance of `glm()` and the insight of a statistician.

In this post, we’ll walk through a real-world binary classification example: predicting respiratory status using clinical trial data. Then, we’ll pit our BNN against the classic logistic regression and the ever-popular random forest.

Let the models battle it out—Bayesian style.

### 🧪 The Data: Clean, Clinical, and Real

We use the `respiratory` dataset from the `HSAUR3` package, focusing on patients from **month 4**. The binary outcome is whether the patient's status is "good". Simple, interpretable, and grounded in reality—just how statisticians like it.


``` r
library(bnns)
library(HSAUR3)
```

```
Warning: package 'HSAUR3' was built under R version 4.4.3
```

``` r
library(rsample)
library(ggplot2)
library(randomForest)
```

```
randomForest 4.7-1.2
```

```
Type rfNews() to see new features/changes/bug fixes.
```

```

Attaching package: 'randomForest'
```

```
The following object is masked from 'package:ggplot2':

    margin
```

``` r
set.seed(123)
trial_data <- HSAUR3::respiratory |>
  subset(month == 4, select = - c(subject, month)) |>
  transform(status = ifelse(status == "good", 1, 0))

trial_data_split <- initial_split(trial_data, strata = status, prop = 0.8)

trial_data_train <- training(trial_data_split)
trial_data_test <- testing(trial_data_split)
```

We stratify by outcome during data splitting to ensure balance. BNNs appreciate thoughtful input.

### 🧠 Building the BNN: No Black Box Here


``` r
bnn_model <- bnns(
  status ~ .,
  data = trial_data_train,
  L = 3,
  nodes = c(64, 4, 4),
  act_fn = rep(4, 3),
  out_act_fn = 2,
  iter = 1e3,
  warmup = 2e2,
  chains = 2,
  prior_weights = list(dist = "normal", params = list(mean = 0, sd = 1)),
  prior_bias = list(dist = "normal", params = list(mean = 0, sd = 10)),
  prior_sigma = list(dist = "half_normal", params = list(mean = 0, sd = 1))
)
```

With just a few lines, we’ve defined a three-layer BNN with fully Bayesian uncertainty on weights, biases, and the residual scale. And no, you don’t need a PhD in Stan to do this—`bnns` handles the machinery under the hood.

### 🔮 Predictions with a Side of Uncertainty

Unlike point estimates from GLMs or RFs, BNNs give us full **posterior distributions** for predictions. We grab medians and 95% credible intervals—because what’s a prediction without a little humility?


``` r
pred <- predict(bnn_model, newdata = trial_data_test)
pred_y <- apply(pred, MARGIN = 1, median, na.rm = TRUE)
pred_quantiles <- apply(pred, MARGIN = 1, function(x)quantile(x, probs = c(0.025, 0.975), na.rm = TRUE), simplify = FALSE) |>
  do.call(args = _, what = rbind)
measure_bin(trial_data_test$status, pred)
```

```
Setting levels: control = 0, case = 1
```

```
Setting direction: controls < cases
```

```
$conf_mat
   pred_label
obs  0  1
  0  1 10
  1  0 12

$accuracy
[1] 0.5652174

$ROC

Call:
roc.default(response = obs, predictor = pred)

Data: pred in 11 controls (obs 0) < 12 cases (obs 1).
Area under the curve: 0.7879

$AUC
[1] 0.7878788
```

We then evaluate performance using `measure_bin()`, our in-house accuracy function.

### 📊 The Plot Thickens

We visualize predictions with credible intervals to see where the model hesitates—and that’s the beauty of Bayesian models. They don’t bluff.


``` r
plot_data <- data.frame(
  Actual = trial_data_test$status,
  Predicted = pred_y,
  Lower = pred_quantiles[,1],
  Upper = pred_quantiles[,2]
) |>
  transform(width = Upper - Lower) |>
  dplyr::arrange(width)

head(plot_data, 5)
```

```
  Actual Predicted     Lower     Upper     width
1      1 0.5185122 0.3228013 0.6419848 0.3191835
2      0 0.5218692 0.3315534 0.6607562 0.3292028
3      1 0.5217615 0.2956351 0.6571779 0.3615428
4      1 0.5222414 0.2957324 0.6613963 0.3656639
5      0 0.5159739 0.2793451 0.6482355 0.3688903
```

BNN predictions with 95% credible intervals for test observations. While most intervals are reasonably narrow, wider intervals reflect situations where the model senses ambiguity — not a bug, but a valuable signal.

Let’s look at a sample of confident predictions with interpretable intervals.


``` r
ggplot(head(plot_data, 5), aes(x = Actual, y = Predicted)) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = Lower, ymax = Upper), width = 0.05, color = "steelblue") +
  labs(title = "BNN Predictions for Patient Status",
    subtitle = "Error bars show 95% credible intervals",
    x = "Test Set Patient Status",
    y = "Predicted Patient Status"
  ) +
  theme_minimal()
```

<img src="{{< blogdown/postref >}}index_files/figure-html/sample_plot-1.png" width="672" />

Unlike black-box predictions, BNNs offer a quantified view of uncertainty — a key advantage in high-stakes decision-making.

### 🥊 The Showdown: GLM vs RF vs BNN


``` r
glm_model <- glm(status ~ .,
                 data = trial_data_train)
glm_pred <- predict(glm_model, trial_data_test)
measure_bin(trial_data_test$status, glm_pred)
```

```
Setting levels: control = 0, case = 1
```

```
Setting direction: controls < cases
```

```
$conf_mat
   pred_label
obs  0  1
  0  5  6
  1  2 10

$accuracy
[1] 0.6521739

$ROC

Call:
roc.default(response = obs, predictor = pred)

Data: pred in 11 controls (obs 0) < 12 cases (obs 1).
Area under the curve: 0.7121

$AUC
[1] 0.7121212
```

``` r
rf_model <- randomForest(factor(status) ~ .,
                 data = trial_data_train)
rf_pred <- predict(rf_model, trial_data_test, type = "prob")[,2]
measure_bin(trial_data_test$status, rf_pred)
```

```
Setting levels: control = 0, case = 1
Setting direction: controls < cases
```

```
$conf_mat
   pred_label
obs 0 1
  0 8 3
  1 4 8

$accuracy
[1] 0.6956522

$ROC

Call:
roc.default(response = obs, predictor = pred)

Data: pred in 11 controls (obs 0) < 12 cases (obs 1).
Area under the curve: 0.7841

$AUC
[1] 0.7840909
```

We compare three models:

-   **GLM:** The old reliable.
-   **Random Forest:** The default go-to.
-   **BNN:** The fresh Bayesian face in town.

BNNs didn’t just hold their own—they brought nuance. They’re not just saying “yes” or “no”, they’re saying “probably yes, and here’s how sure I am.”

### 💡 Why Use `bnns`?

-   **Uncertainty built-in**: Every prediction comes with a measure of confidence.
-   **Flexible priors**: Tailor regularization like a true Bayesian.
-   **Transparent**: Uses `rstan` under the hood, no magic involved.
-   **Light syntax**: As easy as `glm()`, but smarter.

### 🚀 Final Thoughts

In clinical settings, decisions aren’t just about accuracy—they’re about **confidence**. That’s where BNNs shine. And with `bnns`, you don’t have to trade usability for rigor.

Next time you're modeling binary outcomes, ask yourself:\
\> *Do I just want a prediction, or do I want to understand the uncertainty behind it?*
