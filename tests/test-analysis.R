#!/usr/bin/env Rscript
# Integration checks use temporary files and never replace report results.
source("analysis.R")

main <- function() {
  workspace <- tempfile("practice-r-analysis-tests-")
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  raw <- readr::read_csv("data/raw/airquality.csv", show_col_types = FALSE)
  checks <- 0L
  passed <- function(label) {
    checks <<- checks + 1L
    cat(sprintf("PASS %d: %s\n", checks, label))
  }
  run_case <- function(data, name) {
    root <- file.path(workspace, name)
    dir.create(root)
    input <- file.path(root, "input.csv")
    readr::write_csv(data, input)
    log <- file(file.path(root, "run.txt"), open = "wt")
    sink(log)
    on.exit({ sink(); close(log) }, add = TRUE)
    result <- suppressWarnings(tryCatch(run_analysis(input, root), error = identity))
    list(result = result, root = root)
  }
  expect_error <- function(case, pattern) {
    stopifnot(inherits(case$result, "error"),
              grepl(pattern, conditionMessage(case$result), fixed = TRUE))
  }

  wrong_schema <- raw
  names(wrong_schema)[1] <- "Unknown"
  expect_error(run_case(wrong_schema, "schema"), "Expected CSV columns")
  passed("unexpected CSV schema is rejected")

  malformed <- raw
  malformed$Ozone <- as.character(malformed$Ozone)
  malformed$Ozone[1] <- "not_a_number"
  expect_error(run_case(malformed, "parse"), "CSV contains parsing errors")
  passed("malformed numeric input is rejected and parsing errors are recorded")

  short <- raw[complete.cases(raw), ][seq_len(49L), ]
  expect_error(run_case(short, "short"), "At least 50 complete valid observations")
  passed("fewer than 50 valid complete observations are rejected")

  invalid <- raw[1, ]
  invalid$Ozone <- -99
  bad_date <- raw[1, ]
  bad_date$Month <- 2
  bad_date$Day <- 29  # 1973 is not a leap year.
  impossible_date <- raw[1, ]
  impossible_date$Month <- 4
  impossible_date$Day <- 31
  contaminated <- dplyr::bind_rows(raw, raw[1, ], invalid, bad_date, impossible_date)
  case <- run_case(contaminated, "cleaning")
  if (inherits(case$result, "error")) stop(case$result)
  audit <- readr::read_csv(file.path(case$root, "results/tables/data_audit.csv"),
                           show_col_types = FALSE)
  value <- setNames(audit$value, audit$metric)
  stopifnot(value[["raw_rows"]] == 157,
            value[["exact_duplicate_rows"]] == 1,
            value[["invalid_rows_after_deduplication"]] == 3,
            value[["clean_rows"]] == 111)
  reference <- raw[complete.cases(raw), ]
  stopifnot(identical(case$result$cleaned$ozone_ppb, reference$Ozone),
            nrow(case$result$cleaned) == 111,
            !anyDuplicated(case$result$cleaned$date))
  passed("duplicates, physical errors and impossible dates are cleaned without losing valid rows")

  test <- readr::read_csv(file.path(case$root, "results/tables/test_predictions.csv"),
                          show_col_types = FALSE)
  model <- readRDS(file.path(case$root, "results/models/ozone_linear_model.rds"))
  expected <- predict(model, newdata = test)
  stopifnot(nobs(model) == 88, nrow(test) == 23,
            isTRUE(all.equal(as.numeric(expected), test$fit)),
            all(test$lwr <= test$fit & test$fit <= test$upr))
  passed("saved model reproduces held-out predictions and prediction interval bounds")
  cat(sprintf("RESULT: %d/%d analysis integration checks passed\n", checks, 5L))
}

main()
