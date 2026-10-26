#!/usr/bin/env Rscript
# Applied statistical analysis of daily New York air quality, May–September 1973.
# Run: Rscript analysis.R [input_csv] [output_root]
# In RStudio: open Practice_R.Rproj and source("analysis.R").

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

run_analysis <- function(input_csv = "data/raw/airquality.csv", output_root = ".") {
  table_dir <- file.path(output_root, "results", "tables")
  figure_dir <- file.path(output_root, "results", "figures")
  model_dir <- file.path(output_root, "results", "models")
  data_dir <- file.path(output_root, "data", "processed")
  for (path in c(table_dir, figure_dir, model_dir, data_dir)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  save_table <- function(data, name) {
    readr::write_csv(data, file.path(table_dir, paste0(name, ".csv")), na = "")
  }
  save_plot <- function(plot, name, width = 9, height = 6) {
    ggplot2::ggsave(file.path(figure_dir, paste0(name, ".png")), plot,
                    width = width, height = height, units = "in", dpi = 200,
                    device = "png", bg = "white", type = "cairo")
  }
  theme_set(theme_minimal(base_size = 13, base_family = "Noto Sans") +
              theme(plot.title = element_text(face = "bold"),
                    panel.grid.minor = element_blank(),
                    plot.margin = margin(15, 18, 12, 12),
                    legend.position = "bottom"))
  accent <- "#176B87"

  # 1. Import, audit, and clean the actual CSV rather than an in-memory substitute.
  cat("\n1 DATA PREPARATION\n")
  raw <- readr::read_csv(input_csv, col_types = cols(.default = col_double()),
                         show_col_types = FALSE, progress = FALSE)
  expected <- c("Ozone", "Solar.R", "Wind", "Temp", "Month", "Day")
  if (!identical(names(raw), expected)) {
    stop("Expected CSV columns: ", paste(expected, collapse = ", "))
  }
  parse_errors <- readr::problems(raw)
  save_table(parse_errors, "parse_errors")
  if (nrow(parse_errors)) stop("CSV contains parsing errors; see parse_errors.csv")
  missingness <- tibble(variable = names(raw),
                        missing_count = vapply(raw, function(x) sum(is.na(x)), integer(1)))
  save_table(missingness, "missingness")
  duplicate_rows <- duplicated(raw)
  unique_raw <- raw[!duplicate_rows, , drop = FALSE]
  valid_integer <- function(x) is.na(x) | (is.finite(x) & x == floor(x))
  dates <- as.Date(sprintf("1973-%02d-%02d", as.integer(unique_raw$Month),
                           as.integer(unique_raw$Day)), format = "%Y-%m-%d")
  invalid <- rowSums(!is.finite(as.matrix(unique_raw)) &
                      !is.na(as.matrix(unique_raw))) > 0 |
    (!is.na(unique_raw$Ozone) & unique_raw$Ozone < 0) |
    (!is.na(unique_raw$Solar.R) & unique_raw$Solar.R < 0) |
    (!is.na(unique_raw$Wind) & unique_raw$Wind <= 0) |
    (!is.na(unique_raw$Temp) & (unique_raw$Temp < -40 | unique_raw$Temp > 140)) |
    !valid_integer(unique_raw$Month) | !valid_integer(unique_raw$Day) |
    (!is.na(unique_raw$Month) & !unique_raw$Month %in% 1:12) |
    (!is.na(unique_raw$Day) & !unique_raw$Day %in% 1:31) |
    (!is.na(unique_raw$Month) & !is.na(unique_raw$Day) & is.na(dates))
  invalid[is.na(invalid)] <- TRUE
  complete <- stats::complete.cases(unique_raw)
  keep <- !invalid & complete
  cleaned <- unique_raw[keep, , drop = FALSE] |>
    mutate(date = dates[keep], ozone_ppb = Ozone, solar_langley = Solar.R,
           wind_ms = Wind * 0.44704, temp_c = (Temp - 32) * 5 / 9) |>
    select(date, ozone_ppb, solar_langley, wind_ms, temp_c) |>
    arrange(date)
  if (anyDuplicated(cleaned$date)) {
    stop("Conflicting observations share the same date; review the source CSV")
  }
  if (nrow(cleaned) < 50L) stop("At least 50 complete valid observations are required")
  audit <- tibble(
    metric = c("raw_rows", "raw_columns", "parse_errors", "missing_cells",
               "rows_with_missing_values", "exact_duplicate_rows",
               "invalid_rows_after_deduplication", "clean_rows", "removed_rows"),
    value = c(nrow(raw), ncol(raw), nrow(parse_errors), sum(is.na(raw)),
              sum(!complete.cases(raw)), sum(duplicate_rows), sum(invalid),
              nrow(cleaned), nrow(raw) - nrow(cleaned)))
  save_table(audit, "data_audit")
  readr::write_csv(cleaned, file.path(data_dir, "airquality_clean.csv"))
  print(audit, n = Inf)
  print(missingness, n = Inf)

  # 2. Descriptive statistics, including all empirical modes when tied.
  cat("\n2 DESCRIPTIVE STATISTICS\n")
  variables <- c("ozone_ppb", "solar_langley", "wind_ms", "temp_c")
  labels <- c(ozone_ppb = "Озон, ppb", solar_langley = "Сонячна радіація, langley",
              wind_ms = "Швидкість вітру, м/с", temp_c = "Температура, °C")
  describe <- function(variable) {
    x <- cleaned[[variable]]
    distinct <- unique(x)
    frequencies <- tabulate(match(x, distinct))
    modal_frequency <- max(frequencies)
    modes <- sort(distinct[frequencies == modal_frequency])
    tibble(variable = variable, n = length(x), mean = mean(x), median = median(x),
           modes = if (modal_frequency > 1L)
             paste(format(modes, digits = 8, trim = TRUE), collapse = "; ") else
               "No repeated values", mode_frequency = modal_frequency,
           variance = var(x), sd = sd(x), min = min(x), max = max(x),
           q1 = unname(quantile(x, .25)), q3 = unname(quantile(x, .75)))
  }
  descriptive <- bind_rows(lapply(variables, describe))
  save_table(descriptive, "descriptive_statistics")
  print(as.data.frame(descriptive[, 1:10]), row.names = FALSE)
  long <- bind_rows(lapply(variables, function(variable) {
    tibble(variable = variable, value = cleaned[[variable]])
  })) |>
    mutate(label = factor(labels[variable], levels = labels[variables]))

  # 3. Distribution and association plots; Tukey outliers are flags, not deletions.
  cat("\n3 VISUALISATION\n")
  outliers <- bind_rows(lapply(variables, function(variable) {
    x <- cleaned[[variable]]
    q <- quantile(x, c(.25, .75))
    lower <- unname(q[1] - 1.5 * IQR(x))
    upper <- unname(q[2] + 1.5 * IQR(x))
    tibble(variable = variable, lower_fence = lower, upper_fence = upper,
           flagged_count = sum(x < lower | x > upper))
  }))
  save_table(outliers, "outlier_flags")
  save_plot(ggplot(long, aes(value)) +
              geom_histogram(bins = 12, fill = accent, colour = "white") +
              facet_wrap(~label, scales = "free", ncol = 2) +
              labs(title = "Розподіл числових показників", x = NULL,
                   y = "Кількість спостережень"), "histograms", 10, 7)
  save_plot(ggplot(long, aes(x = "", y = value)) +
              geom_boxplot(fill = "#AED6E3", colour = accent, width = .35,
                           outlier.colour = "#B44937") +
              facet_wrap(~label, scales = "free_y", ncol = 2) +
              labs(title = "Діаграми розмаху", x = NULL, y = NULL,
                   subtitle = "Позначені значення збережено після перевірки фізичної правдоподібності"),
            "boxplots", 10, 7)
  scatter <- bind_rows(lapply(c("temp_c", "wind_ms", "solar_langley"), function(v) {
    tibble(variable = v, predictor = cleaned[[v]], ozone_ppb = cleaned$ozone_ppb)
  })) |>
    mutate(label = factor(labels[variable],
                           levels = labels[c("temp_c", "wind_ms", "solar_langley")]))
  save_plot(ggplot(scatter, aes(predictor, ozone_ppb)) +
              geom_point(colour = accent, alpha = .75, size = 1.7) +
              geom_smooth(method = "lm", formula = y ~ x, se = TRUE,
                          colour = "#B44937", fill = "#EED9D5") +
              facet_wrap(~label, scales = "free_x", nrow = 1) +
              labs(title = "Зв'язок озону з метеорологічними показниками",
                   subtitle = "Лінії показують окремі однофакторні залежності, а не підсумкову модель",
                   x = NULL, y = "Озон, ppb"), "scatterplots", 12, 5.5)
  print(outliers, n = Inf)

  # 4. Correlations use all cleaned observations for descriptive exploration.
  cat("\n4 CORRELATION ANALYSIS\n")
  correlation <- cor(as.matrix(cleaned[, variables]), method = "pearson")
  save_table(tibble(variable = rownames(correlation), as.data.frame(correlation)),
             "correlation_matrix")
  pairs <- combn(variables, 2, simplify = FALSE)
  correlations <- bind_rows(lapply(pairs, function(pair) {
    a <- cleaned[[pair[1]]]; b <- cleaned[[pair[2]]]
    test <- cor.test(a, b, method = "pearson")
    tibble(variable_1 = pair[1], variable_2 = pair[2], n = length(a),
           pearson_r = unname(test$estimate), ci_lower = test$conf.int[1],
           ci_upper = test$conf.int[2], p_value = test$p.value,
           spearman_rho = cor(a, b, method = "spearman"))
  })) |>
    mutate(p_adjusted_bh = p.adjust(p_value, method = "BH"))
  save_table(correlations, "correlations")
  print(as.data.frame(correlations), row.names = FALSE)
  heat <- as.data.frame(as.table(correlation))
  names(heat) <- c("variable_1", "variable_2", "correlation")
  heat <- heat |>
    mutate(label_1 = factor(labels[as.character(variable_1)], levels = labels[variables]),
           label_2 = factor(labels[as.character(variable_2)], levels = labels[variables]))
  save_plot(ggplot(heat, aes(label_1, label_2, fill = correlation)) +
              geom_tile(colour = "white") +
              geom_text(aes(label = sprintf("%.2f", correlation)), size = 5) +
              scale_fill_gradient2(low = "#D48B74", mid = "white", high = "#77B7CE",
                                   limits = c(-1, 1), name = "r") +
              coord_equal() +
              labs(title = "Матриця кореляцій Пірсона", x = NULL, y = NULL) +
              theme(axis.text.x = element_text(angle = 30, hjust = 1)),
            "correlation_heatmap", 10, 8)

  # 5. Chronological train/test split prevents later dates from entering training.
  cat("\n5 LINEAR REGRESSION AND PREDICTION\n")
  n_train <- floor(.8 * nrow(cleaned))
  train <- cleaned[seq_len(n_train), ]
  test <- cleaned[seq.int(n_train + 1L, nrow(cleaned)), ]
  split_summary <- bind_rows(lapply(c("train", "test"), function(partition) {
    part <- if (partition == "train") train else test
    tibble(partition = partition, n = nrow(part), start_date = min(part$date),
           end_date = max(part$date), ozone_mean = mean(part$ozone_ppb),
           ozone_sd = sd(part$ozone_ppb), ozone_min = min(part$ozone_ppb),
           ozone_max = max(part$ozone_ppb), temp_mean = mean(part$temp_c),
           wind_mean = mean(part$wind_ms), solar_mean = mean(part$solar_langley))
  }))
  save_table(split_summary, "split_summary")
  model <- lm(ozone_ppb ~ temp_c + wind_ms + solar_langley, data = train)
  model_summary <- summary(model)
  coefficient_matrix <- coef(model_summary)
  intervals <- confint(model)
  coefficients <- tibble(term = rownames(coefficient_matrix),
                          estimate = coefficient_matrix[, 1],
                          std_error = coefficient_matrix[, 2],
                          t_value = coefficient_matrix[, 3],
                          p_value = coefficient_matrix[, 4],
                          ci_lower = intervals[, 1], ci_upper = intervals[, 2])
  save_table(coefficients, "model_coefficients")
  saveRDS(model, file.path(model_dir, "ozone_linear_model.rds"))
  predicted_test <- predict(model, newdata = test, interval = "prediction", level = .95)
  predictions_test <- bind_cols(test, as_tibble(predicted_test)) |>
    mutate(residual = ozone_ppb - fit,
           covered_by_95pi = ozone_ppb >= lwr & ozone_ppb <= upr)
  save_table(predictions_test, "test_predictions")
  scenarios <- tibble(scenario = c("A", "B", "C"), temp_c = c(20, 25, 25),
                       wind_ms = c(4, 4, 3), solar_langley = c(150, 200, 200))
  for (predictor in c("temp_c", "wind_ms", "solar_langley")) {
    observed_range <- range(train[[predictor]])
    if (any(scenarios[[predictor]] < observed_range[1] |
            scenarios[[predictor]] > observed_range[2])) {
      stop("Prediction scenario extrapolates beyond training range for ", predictor)
    }
  }
  scenario_predictions <- bind_cols(scenarios,
                                    as_tibble(predict(model, newdata = scenarios,
                                                      interval = "prediction", level = .95)))
  save_table(scenario_predictions, "scenario_predictions")
  cat(sprintf("Training: %d days (%s to %s); test: %d days (%s to %s)\n",
              nrow(train), min(train$date), max(train$date), nrow(test),
              min(test$date), max(test$date)))
  print(as.data.frame(coefficients), row.names = FALSE)
  print(as.data.frame(scenario_predictions), row.names = FALSE)

  # 6. Fit quality and independent chronological test performance are distinct.
  cat("\n6 MODEL VALIDATION\n")
  residual <- residuals(model)
  fitted_value <- fitted(model)
  rmse <- function(actual, predicted) sqrt(mean((actual - predicted)^2))
  test_sse <- sum((test$ozone_ppb - predicted_test[, "fit"])^2)
  test_sst <- sum((test$ozone_ppb - mean(test$ozone_ppb))^2)
  f_stat <- model_summary$fstatistic
  metrics <- tibble(
    metric = c("clean_n", "train_n", "test_n", "train_r_squared", "train_adjusted_r_squared",
               "model_f_statistic", "model_f_p_value", "train_rmse", "train_residual_sd",
               "test_rmse", "test_mae", "test_r_squared", "test_baseline_rmse",
               "test_mean_reference_rmse",
               "test_prediction_interval_coverage", "train_start", "train_end",
               "test_start", "test_end"),
    value = as.character(c(nrow(cleaned), nrow(train), nrow(test),
                            model_summary$r.squared, model_summary$adj.r.squared,
                            unname(f_stat[1]),
                            pf(f_stat[1], f_stat[2], f_stat[3], lower.tail = FALSE),
                            rmse(train$ozone_ppb, fitted_value), model_summary$sigma,
                            rmse(test$ozone_ppb, predicted_test[, "fit"]),
                            mean(abs(test$ozone_ppb - predicted_test[, "fit"])),
                            1 - test_sse / test_sst,
                            rmse(test$ozone_ppb, rep(mean(train$ozone_ppb), nrow(test))),
                            sqrt(test_sst / nrow(test)),
                            mean(predictions_test$covered_by_95pi),
                            as.character(min(train$date)), as.character(max(train$date)),
                            as.character(min(test$date)), as.character(max(test$date)))))
  save_table(metrics, "metrics")
  shapiro <- shapiro.test(residual)
  auxiliary <- lm(I(residual^2) ~ fitted_value)
  hetero_stat <- length(residual) * summary(auxiliary)$r.squared
  cooks <- cooks.distance(model)
  diagnostics <- tibble(
    metric = c("shapiro_w", "shapiro_p_value", "heteroskedasticity_lm_statistic",
               "heteroskedasticity_df", "heteroskedasticity_p_value",
               "residual_lag1_correlation", "durbin_watson_statistic",
               "max_cooks_distance", "cooks_reference_threshold", "cooks_flagged_count"),
    value = c(unname(shapiro$statistic), shapiro$p.value, hetero_stat, 1,
              pchisq(hetero_stat, df = 1, lower.tail = FALSE),
              cor(head(residual, -1), tail(residual, -1)),
              sum(diff(residual)^2) / sum(residual^2), max(cooks), 4 / nrow(train),
              sum(cooks > 4 / nrow(train))))
  save_table(diagnostics, "model_diagnostics")
  predictors <- c("temp_c", "wind_ms", "solar_langley")
  vif <- bind_rows(lapply(predictors, function(v) {
    aux <- lm(reformulate(setdiff(predictors, v), response = v), data = train)
    tibble(variable = v, vif = 1 / (1 - summary(aux)$r.squared))
  }))
  save_table(vif, "vif")
  residual_table <- train |>
    mutate(fitted = as.numeric(fitted_value), residual = as.numeric(residual),
           standardised_residual = as.numeric(rstandard(model)),
           cooks_distance = as.numeric(cooks), leverage = as.numeric(hatvalues(model)))
  save_table(residual_table, "training_residuals")
  save_plot(ggplot(residual_table, aes(fitted, residual)) +
              geom_point(colour = accent, alpha = .8) +
              geom_hline(yintercept = 0, linetype = "dashed") +
              geom_smooth(method = "loess", formula = y ~ x, se = FALSE,
                          colour = "#B44937") +
              labs(title = "Залишки навчальної моделі", x = "Оцінене значення озону, ppb",
                   y = "Залишок, ppb"), "residuals_vs_fitted")
  save_plot(ggplot(residual_table, aes(sample = standardised_residual)) +
              stat_qq(colour = accent) + stat_qq_line(colour = "#B44937") +
              labs(title = "Перевірка нормальності залишків", x = "Теоретичні квантілі",
                   y = "Стандартизовані залишки"), "residual_qq")
  save_plot(ggplot(predictions_test, aes(date, fit)) +
              geom_ribbon(aes(ymin = lwr, ymax = upr), fill = "#AED6E3", alpha = .6) +
              geom_line(colour = accent, linewidth = .7) +
              geom_point(aes(y = ozone_ppb), colour = "#B44937", size = 2) +
              labs(title = "Прогноз на відкладених спостереженнях",
                   subtitle = "Лінія — прогноз; точки — фактичні значення; смуга — 95% прогнозний інтервал",
                   x = "Дата", y = "Озон, ppb"), "test_forecast", 10, 6)
  save_plot(ggplot(predictions_test, aes(ozone_ppb, fit)) +
              geom_point(colour = accent, size = 2) +
              geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "#B44937") +
              coord_equal() + labs(title = "Фактичні та прогнозовані значення на тесті",
                                   x = "Фактичний озон, ppb", y = "Прогнозований озон, ppb"),
            "test_observed_predicted")
  print(as.data.frame(metrics), row.names = FALSE)
  print(as.data.frame(diagnostics), row.names = FALSE)
  print(as.data.frame(vif), row.names = FALSE)

  # 7. Persist the reproducible run context and its interpretive limitations.
  session_lines <- capture.output(sessionInfo())
  writeLines(trimws(session_lines, which = "right"),
             file.path(output_root, "results", "session-info.txt"))
  interpretation <- c(
    "Interpretation notes",
    "Data source: datasets::airquality, 153 daily New York observations from May–September 1973.",
    "Complete-case analysis drops any row missing one of the six source fields; no imputation is used.",
    "Outliers flagged by the 1.5 IQR rule are retained if physically plausible.",
    "Pearson/Spearman correlations describe all cleaned observations; BH adjusts six Pearson p-values.",
    "The regression specification is fixed in advance: ozone_ppb ~ temp_c + wind_ms + solar_langley.",
    "Only the first chronological 80% of clean rows train the model; the final 20% are held out.",
    "Regression coefficients describe conditional associations, not causal effects.",
    "The heteroskedasticity diagnostic is an LM auxiliary-regression test of squared residuals on fitted values (1 df).",
    "Lag-1 correlation and Durbin–Watson are descriptive checks here, without formal p-values; dates can have gaps.",
    "Shapiro–Wilk, residual plots, influence flags and prediction interval coverage must be considered together.",
    "Normal-error linear prediction intervals can extend below zero; they are reported unchanged, not silently clipped.",
    "Complete-case selection, historical data, temporal gaps and possible residual assumption violations limit generalisation.",
    "Use predictions only within the observed covariate range and this historical context; modern air-quality decisions need new validation."
  )
  writeLines(interpretation, file.path(output_root, "results", "interpretation-notes.txt"))
  cat("\n7 OUTPUT COMPLETE\n",
      "Processed data: data/processed/airquality_clean.csv\n",
      "Statistical tables: results/tables/\n",
      "Eight figures: results/figures/\n",
      "Saved training model: results/models/ozone_linear_model.rds\n",
      "Important: association is not causation; inspect diagnostics before using forecasts.\n", sep = "")
  invisible(list(cleaned = cleaned, model = model, metrics = metrics,
                 coefficients = coefficients, diagnostics = diagnostics))
}

if (sys.nframe() == 0L || interactive()) {
  args <- if (interactive()) character() else commandArgs(trailingOnly = TRUE)
  input_csv <- if (length(args) >= 1L) args[[1]] else "data/raw/airquality.csv"
  output_root <- if (length(args) >= 2L) args[[2]] else "."
  analysis_results <- run_analysis(input_csv, output_root)
}
