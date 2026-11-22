# Development hand-off for Q2 and Q3. All calculations stay in the main R script.
# Run from the project, or use Rscript /full/path/handoff/make_handoff.R.

source_files <- unlist(lapply(sys.frames(), function(frame) frame$ofile))
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
entry_file <- if (length(source_files)) {
  tail(source_files, 1L)
} else if (length(file_arg)) {
  sub("^--file=", "", file_arg[1])
} else {
  character(0)
}

root <- getwd()
if (length(entry_file)) {
  if (!file.exists(entry_file)) {
    entry_file <- gsub("~+~", " ", entry_file, fixed = TRUE)
  }
  root <- dirname(dirname(normalizePath(entry_file, mustWork = TRUE)))
}
if (!file.exists(file.path(root, "305risk-R.Rproj"))) {
  stop("Open 305risk-R.Rproj, or run this file from its handoff/ folder with Rscript.")
}

# Keep the main script's objects together without overwriting the user's workspace.
q1 <- new.env(parent = globalenv())
source(file.path(root, "R", "FIN305_Q1_complete.R"), local = q1)
stopifnot(all(q1$checks$Passed), nrow(q1$R) == length(q1$common_dates))

# Preserve the original dates and gaps; never fill missing market sessions here.
handoff <- data.frame(
  ObsIndex = seq_along(q1$common_dates),
  Date = q1$common_dates,
  SessionIndex = q1$common_sessions,
  SessionGapFromPreviousObs = c(NA_integer_, diff(q1$common_sessions))
)
stock_returns <- as.data.frame(q1$R)
names(stock_returns) <- paste0("r_", q1$symbols)
handoff <- cbind(handoff, stock_returns)
handoff$RfQuoteDate <- q1$rf_quote_date[q1$common_sample]
handoff$RfAnnualYieldPct <- q1$rf_annual_yield_pct[q1$common_sample]
handoff$RfDailyReturn <- q1$rf_common
handoff$GMV_Unconstrained <- as.numeric(q1$R %*% q1$w_gmv)
handoff$Tangency_Unconstrained <- as.numeric(q1$R %*% q1$w_tangency)

stopifnot(!anyDuplicated(handoff$Date), all(diff(handoff$SessionIndex) > 0))
write.csv(handoff, file.path(root, "handoff", "Q2_Q3_handoff.csv"),
          row.names = FALSE, na = "", fileEncoding = "UTF-8")
cat("\nHand-off rows:", nrow(handoff),
    "; market-session gaps:", sum(handoff$SessionGapFromPreviousObs > 1, na.rm = TRUE),
    "\nSaved to handoff/Q2_Q3_handoff.csv (group-only; excluded from Git).\n")
