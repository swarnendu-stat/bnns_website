# A Biostatistician in Early Phase Trials — Part 2

**Date:** July 4, 2026
**Link:** https://swarnendu-stat.netlify.app/post/biostatistician-early-phase-trials-part-2/
**Tags:** clinical trials, biostatistician, early phase, phase 1, 6+2 design, active placebo, R




In [Part 1](/post/biostatistician-early-phase-trials-part-1/), the call hadn't happened yet. The model said proceed; the PI's instinct said wait. Both were reacting to the same cohort, read two different ways.

This post is about the structure underneath that moment — the 6+2 active-plus-placebo cohort design, why it looks the way it does, and what the data actually looks like when you simulate it. Everything below uses dummy data. No real trial, patient, or molecule is represented.

## Why 6+2, and why placebo at all

In a lot of non-oncology, non-vaccine first-in-human work, a 6+2 cohort is the basic unit of the trial: six participants get active drug, two get placebo, and the cohort is reviewed together before anyone decides on the next dose.

Two design choices are doing real work here:

- **Placebo inside every cohort**, not just somewhere in the trial. Without it, a single cohort's adverse event pattern is unanchored — you have no read on background rate, no comparator for borderline findings. With it, even an 8-person cohort gives you something to weigh active-arm signals against.
- **A fixed cohort size of 6+2**, reviewed as a block. This isn't a per-patient escalation rule like 3+3 or a continual reassessment method. It's a planned pause point: enough participants to read a pattern, not so many that you've over-committed before the data says otherwise.

The trade-off is the one from Part 1: pause too readily and the trial slows down for not much added safety information; pause too rarely and a real signal gets buried in a single cohort's noise.

## Simulating a single 6+2 cohort

Let's build one cohort of dummy data: 6 active, 2 placebo, with a binary safety flag (say, a clinically notable lab abnormality) and a continuous response measure.


``` r
library(dplyr)

simulate_cohort <- function(n_active = 6, n_placebo = 2,
                             ae_rate_active = 0.15, ae_rate_placebo = 0.05,
                             mean_active = 2.0, mean_placebo = 0,
                             sd_response = 1.2) {

  active <- tibble(
    arm = "active",
    subject_id = paste0("A", seq_len(n_active)),
    ae_flag = rbinom(n_active, 1, ae_rate_active),
    response = rnorm(n_active, mean = mean_active, sd = sd_response)
  )

  placebo <- tibble(
    arm = "placebo",
    subject_id = paste0("P", seq_len(n_placebo)),
    ae_flag = rbinom(n_placebo, 1, ae_rate_placebo),
    response = rnorm(n_placebo, mean = mean_placebo, sd = sd_response)
  )

  bind_rows(active, placebo)
}

# For the worked example we fix one cohort explicitly, so the numbers
# referenced in the text stay stable from one knit to the next. The
# simulate_cohort() function above is used further down, where we look
# at several cohorts at once.
cohort_1 <- tibble(
  arm        = c(rep("active", 6), rep("placebo", 2)),
  subject_id = c(paste0("A", 1:6), paste0("P", 1:2)),
  ae_flag    = c(1, 0, 0, 0, 0, 0, 0, 0),
  response   = c(2.76, 2.49, 1.87, 3.81, 1.89, 4.42, 1.57, 2.74)
)
cohort_1
```

```
## # A tibble: 8 × 4
##   arm     subject_id ae_flag response
##   <chr>   <chr>        <dbl>    <dbl>
## 1 active  A1               1     2.76
## 2 active  A2               0     2.49
## 3 active  A3               0     1.87
## 4 active  A4               0     3.81
## 5 active  A5               0     1.89
## 6 active  A6               0     4.42
## 7 placebo P1               0     1.57
## 8 placebo P2               0     2.74
```

This single cohort is exactly the kind of dataset a safety review would actually look at: small, mixed-arm, and not obviously decisive in either direction.

## Summarizing a cohort the way a safety review would

A safety review doesn't run a hypothesis test on 8 people. It looks at rates, compares them to placebo, and checks them against pre-specified thresholds.


``` r
summarize_cohort <- function(cohort_data) {
  cohort_data %>%
    group_by(arm) %>%
    summarise(
      n = n(),
      ae_count = sum(ae_flag),
      ae_rate = mean(ae_flag),
      mean_response = mean(response),
      .groups = "drop"
    )
}

summarize_cohort(cohort_1)
```

```
## # A tibble: 2 × 5
##   arm         n ae_count ae_rate mean_response
##   <chr>   <int>    <dbl>   <dbl>         <dbl>
## 1 active      6        1   0.167          2.87
## 2 placebo     2        0   0              2.16
```

That's the entire table a reviewer sees for this cohort: small numbers, an active-arm AE rate that may or may not be worth pausing for, and a placebo arm sitting there as the anchor. This is the table behind the call in Part 1.

## Pre-specifying a stopping rule

The point of designing this in advance is that nobody is deciding what counts as "too many AEs" in the room, in real time, under pressure. A simple pre-specified rule might look like:

> Pause dose escalation if the active-arm AE rate in a cohort exceeds a pre-specified threshold **and** exceeds the placebo-arm rate by a pre-specified margin. Otherwise, proceed.


``` r
apply_stopping_rule <- function(cohort_summary,
                                 ae_threshold = 0.30,
                                 margin_over_placebo = 0.20) {

  active_row <- cohort_summary %>% filter(arm == "active")
  placebo_row <- cohort_summary %>% filter(arm == "placebo")

  active_rate <- active_row$ae_rate
  placebo_rate <- placebo_row$ae_rate

  exceeds_threshold <- active_rate > ae_threshold
  exceeds_margin <- (active_rate - placebo_rate) > margin_over_placebo

  decision <- if (exceeds_threshold && exceeds_margin) "PAUSE" else "PROCEED"

  tibble(
    active_ae_rate = active_rate,
    placebo_ae_rate = placebo_rate,
    exceeds_threshold = exceeds_threshold,
    exceeds_margin = exceeds_margin,
    decision = decision
  )
}

cohort_1_summary <- summarize_cohort(cohort_1)
apply_stopping_rule(cohort_1_summary)
```

```
## # A tibble: 1 × 5
##   active_ae_rate placebo_ae_rate exceeds_threshold exceeds_margin decision
##            <dbl>           <dbl> <lgl>             <lgl>          <chr>   
## 1          0.167               0 FALSE             FALSE          PROCEED
```

With one active-arm AE out of six (a rate of about 0.17), this cohort doesn't cross either threshold — the rule says proceed. That's the quiet, structural version of what the model was saying in Part 1's 9 PM call, before anyone's instinct entered the room.

## Why the rule still isn't the whole story

Notice what the rule does *not* see: it doesn't know that the one AE was a borderline lab value the PI has seen escalate badly in a different drug class. It doesn't know that this is the third cohort in a row with at least one active-arm event, even though no single cohort crossed the threshold. A rule built on one cohort at a time can miss a trend building quietly across cohorts.

That's worth checking directly — not by feel, but by simulating several cohorts in sequence and watching the rate.


``` r
set.seed(8)

cohorts <- lapply(1:5, function(i) simulate_cohort())
cohort_summaries <- lapply(cohorts, summarize_cohort)

trend <- bind_rows(cohort_summaries, .id = "cohort") %>%
  mutate(cohort = as.integer(cohort))

library(ggplot2)

# the two pre-specified stopping-rule thresholds, drawn as reference lines
ae_threshold <- 0.30
margin_over_placebo <- 0.20

ggplot(trend, aes(x = cohort, y = ae_rate, color = arm, group = arm)) +
  geom_hline(yintercept = ae_threshold, linetype = "dashed", color = "grey40") +
  geom_hline(yintercept = margin_over_placebo, linetype = "dotted", color = "grey55") +
  annotate("text", x = 1, y = ae_threshold + 0.04, hjust = 0, size = 3,
           color = "grey30", label = "AE threshold (0.30)") +
  annotate("text", x = 1, y = margin_over_placebo + 0.04, hjust = 0, size = 3,
           color = "grey45", label = "placebo + margin (0.20)") +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_x_continuous(breaks = 1:5) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "AE rate by cohort, active vs. placebo",
    subtitle = "Dashed and dotted lines mark the pre-specified stopping-rule thresholds",
    x = "Cohort",
    y = "AE rate",
    color = "Arm"
  ) +
  theme_minimal()
```

<img src="{{< blogdown/postref >}}index_files/figure-html/multi-cohort-1.png" alt="Active-arm AE rate across five simulated cohorts, compared against placebo" width="672" />

No single cohort here triggers the stopping rule on its own — but watching the active-arm line across cohorts is a different question than watching any one cohort in isolation, and it's exactly the kind of pattern a careful reviewer (or a slightly more sophisticated rule, layering in cumulative evidence rather than per-cohort snapshots) would want to catch.

## Coming up

The 6+2 design is deliberately simple, and that simplicity is the point: it's easy to pre-specify, easy to review, and easy to defend in the room. It is not the only tool available, and it is not always the right one.

In Part 3, I'll step outside the 6+2 world and look at the designs that show up when the question shifts from "is this dose safe" to "what dose is both safe and effective" — Bayesian Logistic Regression Models (BLRM) and the dose-optimization thinking behind the FDA's Project Optimus — with R code for a basic implementation, and a look at when reaching for something more complex than 6+2 actually earns its complexity.

*This post uses entirely simulated data. No real trial, patient, or molecule is represented.*


