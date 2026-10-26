#!/usr/bin/env Rscript
# Original observations from R's documented New York airquality dataset.
args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args)) args[[1]] else "data/raw/airquality.csv"
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(datasets::airquality, output, row.names = FALSE, na = "")
cat(sprintf("Exported %d original observations to %s\n",
            nrow(datasets::airquality), output))
