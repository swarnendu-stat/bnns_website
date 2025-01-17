---
title: "Power of Base R: A Performance Comparison with dplyr"
author: "Swarnendu Chatterjee"
date: "2025-01-17T22:32:22+0530"
slug: "power-of-base-R"
categories: ["R"]
tags: ["R", "dplyr", "tidyverse", "base R"]
---



## Introduction

This presentation explores the performance differences between base R and the dplyr package for various data manipulation tasks. 

- While dplyr is renowned for its intuitive syntax and efficiency, 
- base R functions can sometimes outperform it, particularly in large simulations. 

Understanding these differences can aid in making informed decisions when choosing data wrangling techniques.

## The Iris Dataset

- The **iris** dataset is a classic dataset in statistics and machine learning, often used for demonstrating data manipulation and analysis techniques. 
- It contains measurements of flower characteristics for three species of iris: *setosa*, *versicolor*, and *virginica*.

- Key Features:

- **150 observations**: 50 samples for each species.  
- **4 numeric attributes**: Sepal.Length, Sepal.Width, Petal.Length, Petal.Width  
- **1 categorical attribute**: Species: The species of the iris flower (*setosa*, *versicolor*, *virginica*).

## The Iris Dataset (continued)


```
    Sepal.Length Sepal.Width Petal.Length Petal.Width    Species
1            5.1         3.5          1.4         0.2     setosa
2            4.9         3.0          1.4         0.2     setosa
3            4.7         3.2          1.3         0.2     setosa
51           7.0         3.2          4.7         1.4 versicolor
52           6.4         3.2          4.5         1.5 versicolor
53           6.9         3.1          4.9         1.5 versicolor
101          6.3         3.3          6.0         2.5  virginica
102          5.8         2.7          5.1         1.9  virginica
103          7.1         3.0          5.9         2.1  virginica
```
<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-1-1.png" width="672" />

## Benchmarking Data Manipulation Tasks

## 1. Filter Rows

Filtering rows is a common operation in data analysis. This section benchmarks the efficiency of base R’s subsetting approaches against the dplyr::filter function. While dplyr provides clean syntax, base R’s performance is more efficient.


``` r
mcb_filter <- microbenchmark(
base_0 = iris[iris$Species == "setosa", ],
base_1 = subset(iris, Species == "setosa"),
dplyr = filter(iris, Species == "setosa"),
times = 1e3
)
mcb_filter
```

```
Unit: microseconds
   expr   min    lq     mean median     uq    max neval
 base_0  28.2  31.5  39.5817   35.8  47.10  219.6  1000
 base_1  38.0  44.9  57.0533   54.7  65.00 1620.5  1000
  dplyr 347.7 384.7 420.2611  396.5 414.95 2603.2  1000
```

---


``` r
autoplot(mcb_filter) + ggtitle("Filter: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-2-1.png" width="672" />


``` r
agg_filter <- aggregate(time ~ expr, data = data.frame(mcb_filter), mean)$time
```

So, base R code is on average 11 times **faster** than dplyr::filter. The absolute difference in 10k simulations is 3.806794 seconds.

## 2. Select Columns

Selecting specific columns is fundamental to narrowing down datasets. The comparison here shows how base R indexing and the subset function stack up against dplyr::select in terms of speed.


``` r
mcb_select <- microbenchmark(
base_0 = iris[, c("Sepal.Length", "Petal.Length")],
base_1 = subset(iris, select = c(Sepal.Length, Petal.Length)),
dplyr = select(iris, Sepal.Length, Petal.Length),
times = 1e3
)
mcb_select
```

```
Unit: microseconds
   expr   min    lq     mean median    uq    max neval
 base_0   5.8   6.7  10.7370    9.2  10.6 1388.9  1000
 base_1  25.1  31.7  41.3153   40.9  47.6 1471.5  1000
  dplyr 406.2 436.2 467.0370  448.9 466.2 2545.5  1000
```

---


``` r
autoplot(mcb_select) + ggtitle("Select: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-4-1.png" width="672" />


``` r
agg_select <- aggregate(time ~ expr, data = data.frame(mcb_select), mean)$time
```

So, base R code is on average 43 times **faster** than dplyr::select. The absolute difference in 10k simulations is 4.563 seconds.

## 3. Add/Modify Columns

Adding or modifying columns is crucial for feature engineering. Base R provides multiple methods for this, which are benchmarked here against dplyr::mutate for their computational efficiency.


``` r
mcb_mutate <- microbenchmark(
base_0 = {iris$Sepal_LbyW <- iris$Sepal.Length / iris$Sepal.Width},
base_1 = transform(iris, Sepal_LbyW = Sepal.Length / Sepal.Width),
dplyr = mutate(iris, Sepal_LbyW = Sepal.Length / Sepal.Width),
times = 1e3
)
mcb_mutate
```

```
Unit: microseconds
   expr   min     lq     mean median     uq    max neval
 base_0   3.2   4.40   6.4022   6.25   8.20   25.9  1000
 base_1  27.3  38.70  50.2744  50.00  58.85 1450.9  1000
  dplyr 360.2 401.05 428.6732 415.65 431.45 1964.5  1000
```

---


``` r
autoplot(mcb_mutate) + ggtitle("Mutate: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-6-1.png" width="672" />


``` r
agg_mutate <- aggregate(time ~ expr, data = data.frame(mcb_mutate), mean)$time
```

So, base R code is on average 67 times **faster** than dplyr::mutate. The absolute difference in 10k simulations is 4.22271 seconds.

## 4. Summarise Data

Data summarization helps derive aggregate metrics. This section compares colMeans from base R with dplyr::summarise_if, illustrating their relative performance in summarizing numeric columns.


``` r
mcb_summarise <- microbenchmark(
base_0 = with(iris, data.frame(Sepal_L_mean = mean(Sepal.Length), Sepal_W_sd = sd(Sepal.Width),
Petal_L_mean = mean(Petal.Length), Petal_W_sd = sd(Petal.Width))),
dplyr = summarise(iris, Sepal_L_mean = mean(Sepal.Length), Sepal_W_sd = sd(Sepal.Width),
Petal_L_mean = mean(Petal.Length), Petal_W_sd = sd(Petal.Width)),
times = 1e3
)
mcb_summarise
```

```
Unit: microseconds
   expr   min    lq     mean median     uq    max neval
 base_0 117.2 136.3 165.6190 166.40 179.10 3398.5  1000
  dplyr 589.1 651.8 697.3837 674.85 702.95 2235.8  1000
```

---


``` r
autoplot(mcb_summarise) + ggtitle("Summarise: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-8-1.png" width="672" />


``` r
agg_summarise <- aggregate(time ~ expr, data = data.frame(mcb_summarise), mean)$time
```

So, base R code is on average 4 times **faster** than dplyr::summarise. The absolute difference in 10k simulations is 5.317647 seconds.

## 5. Grouped Summary

Aggregating data by groups is often required for advanced analytics. Base R’s aggregate function is tested here against dplyr's group_by and summarise_all functions to highlight performance differences.


``` r
mcb_grp <- microbenchmark(
base_0 = aggregate(. ~ Species, data = iris, FUN = mean, na.rm = TRUE),
dplyr = iris |>
group_by(Species) |>
summarise_all(mean, na.rm = TRUE) |>
ungroup(),
times = 1e3
)
mcb_grp
```

```
Unit: microseconds
   expr    min      lq      mean  median      uq    max neval
 base_0  638.0  680.80  742.3042  720.70  744.55 2785.4  1000
  dplyr 1935.6 2014.55 2132.6932 2047.95 2110.20 5475.2  1000
```

---


``` r
autoplot(mcb_grp) + ggtitle("Grouped Summarise: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-10-1.png" width="672" />


``` r
agg_grp <- aggregate(time ~ expr, data = data.frame(mcb_grp), mean)$time
```

So, base R code is on average 3 times **faster** than dplyr::grp. The absolute difference in 10k simulations is 13.90389 seconds.

## 6. Sort Data

Sorting is essential for ordering data before visualization or further analysis. The benchmarks here compare the classic base R order approach to the elegant dplyr::arrange.


``` r
mcb_sort <- microbenchmark(
base_0 = iris[with(iris, order(Sepal.Length, Petal.Length)), ],
dplyr = arrange(iris, Sepal.Length, Petal.Length),
times = 1e3
)
mcb_sort
```

```
Unit: microseconds
   expr    min      lq     mean median      uq     max neval
 base_0   39.4   51.20   67.530   73.2   77.85  1301.3  1000
  dplyr 1296.7 1330.55 1432.962 1348.4 1396.05 39396.9  1000
```

---


``` r
autoplot(mcb_sort) + ggtitle("Sort: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-12-1.png" width="672" />


``` r
agg_sort <- aggregate(time ~ expr, data = data.frame(mcb_sort), mean)$time
```

So, base R code is on average 21 times **faster** than dplyr::arrange. The absolute difference in 10k simulations is 13.654316 seconds.

## 7. Join Data

Data joins are indispensable when working with relational datasets. This section demonstrates the efficiency of base R’s merge function compared to dplyr::left_join.


``` r
iris$id <- sample.int(nrow(iris), replace = FALSE)
iris2 <- iris[sample(nrow(iris)),]
mcb_join <- microbenchmark(
base_0 = merge(iris, iris2, by = "id", all.x = TRUE),
dplyr = left_join(iris, iris2, by = "id"),
times = 1e3
)
mcb_join
```

```
Unit: microseconds
   expr   min     lq     mean median     uq    max neval
 base_0 261.2 303.10 344.9787 337.05 359.15 2439.3  1000
  dplyr 612.9 671.35 718.9914 692.65 718.30 2661.7  1000
```

---


``` r
autoplot(mcb_join) + ggtitle("Join: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-14-1.png" width="672" />


``` r
agg_join <- aggregate(time ~ expr, data = data.frame(mcb_join), mean)$time
```

So, base R code is on average 2 times **faster** than dplyr::left_join. The absolute difference in 10k simulations is 3.740127 seconds.

## 8. Group and Apply Function 1

Applying models or transformations to groups of data is a frequent task in statistical workflows. This benchmark showcases the performance of split and lapply in base R versus dplyr::group_map.


``` r
mcb_grp_map <- microbenchmark(
base_0 = lapply(split(iris, iris$Species), function(x) lm(Sepal.Length ~ Petal.Length, data = x)),
dplyr = iris |>
group_by(Species) |>
group_map(~ lm(Sepal.Length ~ Petal.Length, data = .x)),
times = 1e3
)
mcb_grp_map
```

```
Unit: microseconds
   expr    min      lq      mean  median     uq    max neval
 base_0  758.0  817.05  887.7093  843.75  870.8 2685.5  1000
  dplyr 2354.5 2422.50 2558.5587 2458.40 2534.1 5709.2  1000
```

---


``` r
autoplot(mcb_grp_map) + ggtitle("Group Map: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-16-1.png" width="672" />


``` r
agg_grp_map <- aggregate(time ~ expr, data = data.frame(mcb_grp_map), mean)$time
```

So, base R code is on average 3 times **faster** than dplyr::group_map. The absolute difference in 10k simulations is 16.708494 seconds.

## 9. Group and Apply Function 2

Complex operations on grouped data are common in analytical pipelines. This comparison highlights the performance of base R’s split and lapply with a row-binding step versus dplyr::group_modify.


``` r
mcb_grp_mod <- microbenchmark(
base_0 = do.call(rbind, lapply(split(iris, iris$Species), function(x) 
data.frame(summary(lm(Sepal.Length ~ Petal.Length, data = x))$coefficients))),
dplyr = iris |>
group_by(Species) |>
group_modify(~ data.frame(summary(lm(Sepal.Length ~ Petal.Length, data = .x))$coefficients)) |>
ungroup(),
times = 1e3
)
mcb_grp_mod
```

```
Unit: milliseconds
   expr    min      lq     mean  median     uq     max neval
 base_0 1.3785 1.47355 1.608932 1.50645 1.5597 40.7367  1000
  dplyr 4.3195 4.47495 4.716570 4.58045 4.7456  8.3596  1000
```

---


``` r
autoplot(mcb_grp_mod) + ggtitle("Group Modify: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-18-1.png" width="672" />


``` r
agg_grp_mod <- aggregate(time ~ expr, data = data.frame(mcb_grp_mod), mean)$time
```

So, base R code is on average 3 times **faster** than dplyr::group_modify. The absolute difference in 10k simulations is 31.076376 seconds.

## 10. Rowwise


``` r
mcb_rowwise <- microbenchmark(base_0 = transform(iris, 
Sepal_sd = apply(cbind(Sepal.Length, Sepal.Width), 1, sd),
Petal_sd = apply(cbind(Petal.Length, Petal.Width), 1, sd)),
dplyr = iris |>
dplyr::rowwise() |>
dplyr::mutate(Sepal_sd = sd(c(Sepal.Length, Sepal.Width)),
Petal_sd = sd(c(Petal.Length, Petal.Width))) |>
dplyr::ungroup(),
times = 1e3)
```

---


``` r
autoplot(mcb_rowwise) + ggtitle("Rowwise: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-20-1.png" width="672" />


``` r
agg_rowwise <- aggregate(time ~ expr, data = data.frame(mcb_rowwise), mean)$time
```

So, base R code is on average 3 times **faster** than dplyr::rowwise. The absolute difference in 10k simulations is 21.667426 seconds.

## 11. Count Rows by Group

Counting the number of rows by group is a simple yet frequent operation. The comparison here emphasizes the efficiency of base R’s table function against dplyr::count.


``` r
mcb_count <- microbenchmark(
base_0 = table(iris$Species),
dplyr = iris |> count(Species),
times = 1e3
)
mcb_count
```

```
Unit: microseconds
   expr    min      lq      mean  median      uq    max neval
 base_0   14.9   21.05   32.5562   36.30   39.90 1374.4  1000
  dplyr 1298.7 1348.40 1433.3286 1373.65 1428.55 3183.0  1000
```

---


``` r
autoplot(mcb_count) + ggtitle("Count: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-22-1.png" width="672" />


``` r
agg_count <- aggregate(time ~ expr, data = data.frame(mcb_count), mean)$time
```

So, base R code is on average 44 times **faster** than dplyr::count. The absolute difference in 10k simulations is 14.007724 seconds.

## 12. Identify Distinct Rows

Identifying unique rows is crucial for deduplication. This benchmark compares base R’s unique function with dplyr::distinct, shedding light on performance differences for this operation.


``` r
mcb_distinct <- microbenchmark(
base_0 = unique(rbind(iris, iris)),
dplyr = distinct(rbind(iris, iris)),
times = 1e3
)
mcb_distinct
```

```
Unit: microseconds
   expr   min    lq     mean median     uq    max neval
 base_0 564.2 598.0 656.7336 612.90 638.05 2461.0  1000
  dplyr 232.4 261.8 286.6282 274.35 289.75 2160.5  1000
```

---


``` r
autoplot(mcb_distinct) + ggtitle("Distinct: Base R vs dplyr")
```

<img src="{{< blogdown/postref >}}index_files/figure-html/unnamed-chunk-24-1.png" width="672" />


``` r
agg_distinct <- aggregate(time ~ expr, data = data.frame(mcb_distinct), mean)$time
```

So, base R code is on average 2 times **slower** than dplyr::distinct. The absolute difference in 10k simulations is 3.701054 seconds. 

## Summary

Given that these functions are very commonly used, it is fair to assume that these functions are used at least 5 times in a standard simulation code. If that simulation is repeated for 10k times, then the total gain we have by using base R is at least 10.7472875 minutes.

## Conclusion

This analysis demonstrates

- that while dplyr offers user-friendly functions and a consistent syntax, 
- base R can often be **faster** for basic operations, especially with large datasets. 

The choice between base R and dplyr should consider both readability and computational efficiency, dependent on the scale and complexity of your data tasks.

- For intensive data simulations, careful function choice can lead to significant performance gains, 
- underscoring the importance of benchmarking and profiling in the R language.
