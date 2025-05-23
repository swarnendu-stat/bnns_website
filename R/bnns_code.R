library(bnns)
library(mlbench)
library(rsample)
library(ggplot2)

set.seed(123)
data("PimaIndiansDiabetes2")
trial_data <- PimaIndiansDiabetes2 |>
  transform(diabetes = ifelse(diabetes == "pos", 1, 0)) |>
  # transform(diabetes = factor(diabetes, levels = c("neg", "pos"))) |>
  na.omit()

trial_data_split <- initial_split(trial_data, strata = diabetes, prop = 0.8)

trial_data_train <- training(trial_data_split)
trial_data_test <- testing(trial_data_split)

bnn_model <- bnns(
  diabetes ~ .,
  data = trial_data_train,
  L = 2,
  nodes = c(24, 12),  # c(64, 4) gave 0.836  (8, 4) gave 0.8287 (64, 32) gave 0.833 with 1k|| (64, 16, 4) with (4, 1, 4) gave 0.837|| (16, 8) gave 0.83 || (24, 12) gave 0.835
  act_fn = c(4, 1),
  out_act_fn = 2,
  iter = 0.1e4,
  warmup = 0.05e4,
  chains = 4,
  cores = 4,
  prior_weights = list(dist = "cauchy", params = list(mu = 0, sigma = 0.3)),  # Cauchy for sparsity
  prior_bias = list(dist = "cauchy", params = list(mu = 0, sigma = 0.3))  # 0.82 AUC came with list(dist = "normal", params = list(mean = 0, sd = 0.5))
)
pred <- predict(bnn_model, newdata = trial_data_test)
pred_y <- apply(pred, MARGIN = 1, median, na.rm = TRUE)
pred_quantiles <- apply(pred, MARGIN = 1, function(x)quantile(x, probs = c(0.025, 0.975), na.rm = TRUE), simplify = FALSE) |>
  do.call(args = _, what = rbind)
measure_bin(trial_data_test$diabetes, pred)

plot_data <- data.frame(
  Actual = trial_data_test$diabetes,
  Predicted = pred_y,
  Lower = pred_quantiles[,1],
  Upper = pred_quantiles[,2]
) |>
  transform(width = Upper - Lower) |>
  dplyr::arrange(width)

head(plot_data, 5)

ggplot(plot_data, aes(x = Actual, y = Predicted)) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = Lower, ymax = Upper), width = 0.05, color = "steelblue") +
  labs(title = "BNN Predictions for Patient Status",
       subtitle = "Error bars show 95% credible intervals",
       x = "Test Set Patient Status",
       y = "Predicted Patient Status"
  ) +
  theme_minimal()

glm_model <- glm(
  diabetes ~ .,
  data = trial_data_train)
pred_glm <- predict(glm_model, trial_data_test)
measure_bin(trial_data_test$diabetes, pred_glm)

rf_model <- randomForest(
  factor(diabetes) ~ .,
  data = trial_data_train)
pred_rf <- predict(rf_model, trial_data_test, type = "prob")
measure_bin(trial_data_test$diabetes, pred_rf)

# bnn_model <- bnns(
#   diabetes ~ .,
#   data = trial_data_train,
#   L = 2,
#   nodes = c(16, 8),  # c(32, 16, 4)
#   act_fn = c(4, 1),
#   out_act_fn = 2,
#   iter = 5e3,
#   warmup = 2e3,
#   chains = 2,
#   prior_weights = list(dist = "normal", params = list(mean = 0, sd = 1)),
#   prior_bias = list(dist = "normal", params = list(mean = 0, sd = 1)),
#   prior_sigma = list(dist = "half_normal", params = list(mean = 0, sd = 0.5))
# )

# bnn_model <- bnns(
#   diabetes ~ .,
#   data = trial_data_train,
#   L = 2,
#   nodes = c(12, 6),
#   act_fn = c(4, 3),
#   out_act_fn = 2,
#   iter = 0.5e4,
#   warmup = 1.5e3,
#   chains = 4,
#   cores = 4,
#   prior_weights = list(dist = "cauchy", params = list(mu = 0, sigma = 0.3)),  # Cauchy for sparsity
#   prior_bias = list(dist = "cauchy", params = list(mu = 0, sigma = 0.3))  # 0.82 AUC came with list(dist = "normal", params = list(mean = 0, sd = 0.5))
# )

# bnn_model <- bnns(
#   diabetes ~ .,
#   data = trial_data_train,
#   L = 2,
#   nodes = c(32, 8),  # c(64, 4) gave 0.836
#   act_fn = c(4, 1),
#   out_act_fn = 2,
#   iter = 0.5e4,
#   warmup = 1.5e3,
#   chains = 4,
#   cores = 4,
#   prior_weights = list(dist = "cauchy", params = list(mu = 0, sigma = 0.5)),  # Cauchy for sparsity
#   prior_bias = list(dist = "cauchy", params = list(mu = 0, sigma = 0.5))  # 0.82 AUC came with list(dist = "normal", params = list(mean = 0, sd = 0.5))
# )
