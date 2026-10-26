#!/usr/bin/env Rscript

main <- function() {
  checks <- 0L
  pass <- function(label) {
    checks <<- checks + 1L
    cat(sprintf("PASS %d: %s\n", checks, label))
  }

  fit <- stats::lm(mpg ~ wt, data = datasets::mtcars)
  stopifnot(
    isTRUE(all.equal(unname(stats::coef(fit)),
                     c(37.285126167342, -5.34447157272268), tolerance = 1e-10)),
    summary(fit)$r.squared > 0.75,
    max(abs(crossprod(stats::model.matrix(fit), stats::residuals(fit)))) < 1e-9,
    all(is.finite(stats::predict(fit, interval = "confidence")))
  )
  pass("linear model, residuals, and confidence intervals")

  records <- data.frame(
    місто = c("Київ", "Львів", "Дніпро"),
    значення = c(12.5, NA_real_, -3.25),
    примітка = c("Текст, із комою", "Лапки: \"дані\"", "Українська мова"),
    check.names = FALSE
  )
  csv <- tempfile("practice-r-", fileext = ".csv")
  utils::write.csv(records, csv, row.names = FALSE, fileEncoding = "UTF-8")
  restored <- utils::read.csv(csv, fileEncoding = "UTF-8",
                             stringsAsFactors = FALSE, check.names = FALSE)
  stopifnot(identical(records, restored))
  pass("UTF-8 CSV roundtrip with Ukrainian text and missing values")

  stopifnot(requireNamespace("Matrix", quietly = TRUE))
  sparse <- Matrix::sparseMatrix(
    i = c(1L, 2L, 2L, 3L, 3L),
    j = c(1L, 1L, 2L, 2L, 3L),
    x = c(4, 1, 3, 1, 2),
    dims = c(3L, 3L), symmetric = TRUE
  )
  rhs <- c(1, 2, 3)
  solution <- solve(sparse, rhs)
  stopifnot(
    inherits(sparse, "sparseMatrix"),
    max(abs(as.numeric(sparse %*% solution) - rhs)) < 1e-12,
    isTRUE(all.equal(as.numeric(solution), c(2 / 9, 1 / 9, 13 / 9),
                     tolerance = 1e-12))
  )
  pass("Matrix sparse linear-system solve")

  stopifnot(isTRUE(capabilities("cairo")))
  png <- tempfile("practice-r-", fileext = ".png")
  grDevices::png(png, width = 640L, height = 480L, type = "cairo")
  tryCatch({
    graphics::plot(datasets::mtcars$wt, datasets::mtcars$mpg,
                   xlab = "Weight (1000 lb)", ylab = "Miles per gallon",
                   main = "R environment validation", pch = 19L)
    graphics::abline(fit, col = "steelblue", lwd = 2L)
  }, finally = grDevices::dev.off())
  signature <- readBin(png, what = "raw", n = 8L)
  stopifnot(
    file.info(png)$size > 1024,
    identical(signature, as.raw(c(137, 80, 78, 71, 13, 10, 26, 10)))
  )
  pass("headless Cairo plot produces a valid nonempty PNG")

  stopifnot(requireNamespace("renv", quietly = TRUE))
  stopifnot(is.function(getExportedValue("renv", "restore")))
  pass(sprintf("renv %s namespace loads", utils::packageVersion("renv")))

  cat(sprintf("RESULT: %d/%d checks passed\n", checks, 5L))
}

main()
