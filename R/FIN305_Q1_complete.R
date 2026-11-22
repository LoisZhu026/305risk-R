# ============================================================
# FIN305 Risk Management for Business - Group Project
# Question 1: Return analysis and mean-variance portfolio analysis
#
# This script is self-contained with respect to calculations:
#   * It reads the original CSMAR adjusted-price/status data,
#     the trading calendar, and the 3-month Treasury-bill quotes.
#   * It calculates simple/log returns and the risk-free daily return
#     inside R (no Python-prepared return files are used).
#   * It writes all Q1 CSV tables, frontier points, figures,
#     numerical checks, and sessionInfo().
#
# Run: open 305risk-R.Rproj, then open this file and click Source.
# Required packages: none (base R only).
# ============================================================

## 0. Locate project folders and initialise -------------------

days <- 252
weight_cap <- 0.30
set.seed(3052026)

find_project_root <- function(marker = "305risk-R.Rproj") {
  starts <- getwd()

  # Rscript supplies the script filename as a --file argument.
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg)) {
    script_path <- sub("^--file=", "", file_arg[1])
    if (!file.exists(script_path)) {
      # Some R launchers represent spaces in commandArgs() as ~+~.
      script_path <- gsub("~+~", " ", script_path, fixed = TRUE)
    }
    starts <- c(dirname(normalizePath(script_path, mustWork = TRUE)), starts)
  }

  # Prefer the actual sourced file over a calling wrapper or working directory.
  ofile <- unlist(lapply(sys.frames(), function(frame) frame$ofile))
  if (length(ofile)) {
    starts <- c(dirname(normalizePath(tail(ofile, 1L), mustWork = TRUE)), starts)
  }

  for (candidate in unique(starts)) {
    candidate <- normalizePath(candidate, winslash = "/", mustWork = TRUE)
    repeat {
      if (file.exists(file.path(candidate, marker))) return(candidate)
      parent <- dirname(candidate)
      if (parent == candidate) break
      candidate <- parent
    }
  }

  stop("Cannot find the project root. Open 305risk-R.Rproj, or keep this script inside the project folder.")
}

# The project marker defines one root for Q1, Q2 and Q3.
# Source data are stored under the repository root data/ folder.
root <- find_project_root()
data_dir <- file.path(root, "data")
out_dir <- root
csv_dir <- file.path(out_dir, "CSV")
fig_dir <- file.path(out_dir, "Figures")
required_inputs <- c("csmar_adjusted_long.csv", "trading_calendar.csv", "treasury_3m_quotes.csv")
if (!all(file.exists(file.path(data_dir, required_inputs)))) {
  stop("Source CSV files are missing. Keep all three input CSVs under the project's data folder.")
}
dir.create(csv_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

read_input <- function(filename) {
  read.csv(
    file.path(data_dir, filename),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8-BOM"
  )
}

write_output <- function(x, filename) {
  write.csv(
    x, file.path(csv_dir, filename),
    row.names = FALSE, na = "", fileEncoding = "UTF-8"
  )
}

symbols <- c("000651", "002032", "600060", "600690", "600839")
assets <- c("Gree Electric", "Supor", "Hisense Visual Technology",
            "Haier Smart Home", "Sichuan Changhong")
n_assets <- length(assets)

## 1. Rebuild daily returns from original CSMAR inputs --------

raw <- read_input("csmar_adjusted_long.csv")
calendar <- read_input("trading_calendar.csv")
quotes <- read_input("treasury_3m_quotes.csv")

raw$Date <- as.Date(raw$TradingDate)
raw$Symbol6 <- sprintf("%06d", as.integer(raw$Symbol))
raw$Filling <- as.numeric(raw$Filling)
raw$StateCode <- as.numeric(raw$StateCode)
raw$AdjustedClose <- as.numeric(raw$ClosePrice)

calendar$Date <- as.Date(calendar$Date)
calendar$SessionIndex <- as.numeric(calendar$SessionIndex)
calendar <- calendar[order(calendar$Date), ]
calendar <- calendar[!duplicated(calendar$Date), ]
calendar_dates_all <- calendar$Date
session_all <- calendar$SessionIndex

# The first calendar row (31 Dec 2009) is retained only as the
# previous-price baseline. The analysed period starts on 4 Jan 2010.
panel_all <- data.frame(Date = calendar_dates_all)
price_all <- matrix(NA_real_, nrow = length(calendar_dates_all),
                    ncol = n_assets, dimnames = list(NULL, assets))
simple_all <- price_all
log_all <- price_all
eligible_all <- matrix(FALSE, nrow = length(calendar_dates_all),
                       ncol = n_assets, dimnames = list(NULL, assets))

for (j in seq_along(symbols)) {
  z <- raw[raw$Symbol6 == symbols[j], ]
  z <- z[order(z$Date), ]
  match_idx <- match(calendar_dates_all, z$Date)

  px <- z$AdjustedClose[match_idx]
  filling <- z$Filling[match_idx]
  state <- z$StateCode[match_idx]

  normal_today <- !is.na(filling) & filling == 0 &
                  !is.na(state) & state == 0 &
                  is.finite(px) & px > 0
  normal_previous <- c(FALSE, head(normal_today, -1))
  previous_px <- c(NA_real_, head(px, -1))

  eligible <- normal_today & normal_previous &
              is.finite(previous_px) & previous_px > 0

  simple <- rep(NA_real_, length(px))
  logret <- rep(NA_real_, length(px))
  simple[eligible] <- px[eligible] / previous_px[eligible] - 1
  logret[eligible] <- log(px[eligible] / previous_px[eligible])

  price_all[, j] <- px
  simple_all[, j] <- simple
  log_all[, j] <- logret
  eligible_all[, j] <- eligible
}

colnames(price_all) <- paste0(assets, "_AdjustedClose")
colnames(simple_all) <- paste0(assets, "_SimpleReturn")
colnames(log_all) <- paste0(assets, "_LogReturn")

# Exclude the 31 Dec 2009 baseline row from the reported sample.
sample_rows <- which(calendar_dates_all >= as.Date("2010-01-01"))
sample_dates <- calendar_dates_all[sample_rows]
sample_sessions <- session_all[sample_rows]
price_mat <- price_all[sample_rows, , drop = FALSE]
simple_mat <- simple_all[sample_rows, , drop = FALSE]
log_mat <- log_all[sample_rows, , drop = FALSE]
eligible_mat <- eligible_all[sample_rows, , drop = FALSE]

common_sample <- complete.cases(simple_mat)
common_n <- sum(common_sample)
sample_years <- as.integer(format(max(sample_dates), "%Y")) -
                as.integer(format(min(sample_dates[common_sample]), "%Y")) + 1L

if (common_n < 2520) {
  stop("The common sample contains fewer than 2,520 non-missing observations.")
}
if (sample_years < 15) {
  stop("The common sample does not cover at least 15 calendar years.")
}
if (any(!is.finite(simple_mat[common_sample, ]))) {
  stop("Non-finite stock returns found in the common sample.")
}

## 2. Rebuild risk-free daily returns in R ---------------------

quotes$QuoteDate <- as.Date(quotes$QuoteDate)
quotes$AnnualYieldPct <- as.numeric(quotes$AnnualYieldPct)
quotes <- quotes[order(quotes$QuoteDate), ]
quotes <- quotes[!duplicated(quotes$QuoteDate, fromLast = TRUE), ]

# Use the latest available quote strictly before each return date.
# This reproduces the lagged quote alignment in the supplied source data.
quote_index <- findInterval(
  as.numeric(sample_dates - 1),
  as.numeric(quotes$QuoteDate)
)
if (any(quote_index < 1)) {
  stop("No Treasury-bill quote is available before at least one sample date.")
}
rf_quote_date <- quotes$QuoteDate[quote_index]
rf_annual_yield_pct <- quotes$AnnualYieldPct[quote_index]
rf_daily <- (1 + rf_annual_yield_pct / 100)^(1 / days) - 1

if (any(rf_quote_date >= sample_dates)) {
  stop("Risk-free quote alignment error: a quote date is not earlier than its return date.")
}
if (any(!is.finite(rf_daily))) {
  stop("Non-finite daily risk-free returns found.")
}

## 3. Descriptive statistics ----------------------------------

R <- simple_mat[common_sample, , drop = FALSE]
log_R <- log_mat[common_sample, , drop = FALSE]
rf_common <- rf_daily[common_sample]
common_dates <- sample_dates[common_sample]
common_sessions <- sample_sessions[common_sample]

# AC1 uses only adjacent market-session pairs inside the common sample.
# This avoids pairing observations separated by a suspension or a missing day.
adjacent_pair_index <- which(diff(common_sessions) == 1)

skewness_fn <- function(x) {
  x <- x[is.finite(x)]
  m <- mean(x)
  second_moment <- mean((x - m)^2)
  if (length(x) < 3 || second_moment <= 0) return(NA_real_)
  mean((x - m)^3) / second_moment^(3 / 2)
}

kurtosis_fn <- function(x) {
  x <- x[is.finite(x)]
  m <- mean(x)
  second_moment <- mean((x - m)^2)
  if (length(x) < 4 || second_moment <= 0) return(NA_real_)
  mean((x - m)^4) / second_moment^2
}

ac1_adjacent <- function(x) {
  if (length(adjacent_pair_index) < 2) return(c(AC1 = NA_real_, AC1_Pairs = 0))
  x1 <- x[adjacent_pair_index]
  x2 <- x[adjacent_pair_index + 1]
  ok <- is.finite(x1) & is.finite(x2)
  if (sum(ok) < 2 || sd(x1[ok]) == 0 || sd(x2[ok]) == 0) {
    return(c(AC1 = NA_real_, AC1_Pairs = sum(ok)))
  }
  c(AC1 = cor(x1[ok], x2[ok]), AC1_Pairs = sum(ok))
}

describe_one <- function(x, label, symbol_label) {
  x <- x[is.finite(x)]
  ac <- ac1_adjacent(x)
  c(
    Asset = label,
    Symbol = symbol_label,
    N = length(x),
    Mean = mean(x),
    Median = median(x),
    StdDev = sd(x),
    Skewness = skewness_fn(x),
    Kurtosis = kurtosis_fn(x),
    ExcessKurtosis = kurtosis_fn(x) - 3,
    Minimum = min(x),
    Q1 = unname(quantile(x, 0.25, names = FALSE)),
    Q3 = unname(quantile(x, 0.75, names = FALSE)),
    Maximum = max(x),
    AC1 = unname(ac["AC1"]),
    AC1_Pairs = unname(ac["AC1_Pairs"])
  )
}

# The helper above receives the common-sample vector, so adjacent_pair_index
# is valid for both stock and risk-free series.
simple_stats_rows <- lapply(seq_along(assets), function(j) {
  describe_one(R[, j], assets[j], symbols[j])
})
simple_stats_rows[[length(simple_stats_rows) + 1]] <-
  describe_one(rf_common, "Risk-free (3M Chinese T-bill)", "3M-T-bill")

simple_stats <- as.data.frame(do.call(rbind, simple_stats_rows),
                              stringsAsFactors = FALSE)
numeric_stats <- setdiff(names(simple_stats), c("Asset", "Symbol"))
simple_stats[numeric_stats] <- lapply(simple_stats[numeric_stats], as.numeric)
write_output(simple_stats, "Q1a_descriptive_statistics.csv")

log_stats_rows <- lapply(seq_along(assets), function(j) {
  describe_one(log_R[, j], assets[j], symbols[j])
})
log_stats <- as.data.frame(do.call(rbind, log_stats_rows),
                            stringsAsFactors = FALSE)
log_stats[numeric_stats] <- lapply(log_stats[numeric_stats], as.numeric)
write_output(log_stats, "Q1a_log_descriptive_statistics.csv")

## 4. Export full input/return panel (3,643 trading dates) -----

full_output <- data.frame(Date = sample_dates)
for (j in seq_along(assets)) {
  full_output[[paste0(assets[j], "_AdjustedClose")]] <- price_mat[, j]
  full_output[[paste0(assets[j], "_SimpleReturn")]] <- simple_mat[, j]
  full_output[[paste0(assets[j], "_LogReturn")]] <- log_mat[, j]
  full_output[[paste0(assets[j], "_ReturnEligible")]] <- eligible_mat[, j]
}
full_output$RfAnnualYieldPct <- rf_annual_yield_pct
full_output$RfQuoteDate <- rf_quote_date
full_output$RfDailyReturn <- rf_daily
full_output$CommonSample <- common_sample
write_output(full_output, "Q1_returns_and_prices.csv")

## 5. Portfolio moments and analytical unconstrained solutions --

mu <- colMeans(R)
S <- cov(R)
if (qr(S)$rank < n_assets) stop("The sample covariance matrix is singular.")
Sinv <- solve(S)
ones <- rep(1, n_assets)
rf_mean <- mean(rf_common)
rf_annual_pct <- rf_mean * days * 100

port_return <- function(w) as.numeric(sum(w * mu))
port_variance <- function(w) as.numeric(crossprod(w, S %*% w))
port_volatility <- function(w) sqrt(max(port_variance(w), 0))
port_sharpe <- function(w) (port_return(w) - rf_mean) / port_volatility(w)

w_gmv <- as.numeric(Sinv %*% ones)
w_gmv <- w_gmv / sum(w_gmv)

excess <- mu - rf_mean
direction <- as.numeric(Sinv %*% excess)
if (abs(sum(direction)) < 1e-12) {
  stop("Tangency portfolio normalisation is undefined.")
}
w_tangency <- direction / sum(direction)

make_metrics <- function(name, w) {
  rd <- port_return(w)
  vd <- port_volatility(w)
  sr <- (rd - rf_mean) / vd
  data.frame(
    Portfolio = name,
    ExpectedReturnDaily = rd,
    VolatilityDaily = vd,
    SharpeDaily = sr,
    ExpectedReturnAnnualPct = rd * days * 100,
    VolatilityAnnualPct = vd * sqrt(days) * 100,
    SharpeAnnual = sr * sqrt(days)
  )
}

metrics_unconstrained <- rbind(
  make_metrics("GMV_Unconstrained", w_gmv),
  make_metrics("Tangency_Unconstrained", w_tangency)
)

## 6. 10,000 broad random portfolios ---------------------------

# Equal-weight centre plus zero-sum Gaussian perturbations.
# This produces fully invested portfolios and allows short positions.
random_count <- 10000
Z <- matrix(rnorm(random_count * n_assets, mean = 0, sd = 0.75),
            nrow = random_count, ncol = n_assets)
random_weights <- sweep(Z - rowMeans(Z), 2, rep(1 / n_assets, n_assets), "+")

random_return <- as.numeric(random_weights %*% mu)
random_volatility <- sqrt(rowSums((random_weights %*% S) * random_weights))
random_sharpe <- (random_return - rf_mean) / random_volatility

random_portfolios <- data.frame(
  PortfolioID = seq_len(random_count),
  ExpectedReturnDaily = random_return,
  VolatilityDaily = random_volatility,
  SharpeDaily = random_sharpe,
  ExpectedReturnAnnualPct = random_return * days * 100,
  VolatilityAnnualPct = random_volatility * sqrt(days) * 100,
  SharpeAnnual = random_sharpe * sqrt(days)
)
for (j in seq_along(assets)) {
  random_portfolios[[paste0("Weight_", symbols[j])]] <- random_weights[, j]
}
write_output(random_portfolios, "Q1b_random_10000_portfolios.csv")

i_random_gmv <- which.min(random_volatility)
i_random_tan <- which.max(random_sharpe)
make_extreme_row <- function(label, i = NA_integer_, w) {
  if (!is.na(i)) {
    rd <- random_return[i]
    vd <- random_volatility[i]
    sr <- random_sharpe[i]
  } else {
    rd <- port_return(w)
    vd <- port_volatility(w)
    sr <- port_sharpe(w)
  }
  row <- data.frame(
    Portfolio = label,
    ExpectedReturnDaily = rd,
    VolatilityDaily = vd,
    SharpeDaily = sr,
    ExpectedReturnAnnualPct = rd * days * 100,
    VolatilityAnnualPct = vd * sqrt(days) * 100,
    SharpeAnnual = sr * sqrt(days)
  )
  weight_row <- as.data.frame(as.list(as.numeric(w)))
  names(weight_row) <- paste0("Weight_", symbols)
  cbind(row, weight_row)
}

random_extremes <- rbind(
  make_extreme_row("Random_minimum_volatility", i_random_gmv,
                   random_weights[i_random_gmv, ]),
  make_extreme_row("Analytical_GMV", w = w_gmv),
  make_extreme_row("Random_maximum_Sharpe", i_random_tan,
                   random_weights[i_random_tan, ]),
  make_extreme_row("Analytical_Tangency", w = w_tangency)
)
write_output(random_extremes, "Q1b_random_extremes_vs_analytical.csv")

## 7. Efficient frontier helper and unconstrained frontier ------

# Solve min w'Sw subject to Cw=b. Return NULL if constraints are
# linearly dependent or the system cannot be solved.
eq_min <- function(C, b) {
  C <- as.matrix(C)
  if (qr(t(C), tol = 1e-10)$rank < nrow(C)) return(NULL)
  middle <- C %*% Sinv %*% t(C)
  answer <- tryCatch(
    Sinv %*% t(C) %*% solve(middle, as.numeric(b)),
    error = function(e) NULL
  )
  if (is.null(answer)) return(NULL)
  as.numeric(answer)
}

target_unconstrained <- seq(
  from = port_return(w_gmv),
  to = max(mu) * 1.10,
  length.out = 400
)
frontier_u_weights <- matrix(NA_real_, nrow = length(target_unconstrained),
                             ncol = n_assets)
for (k in seq_along(target_unconstrained)) {
  target <- target_unconstrained[k]
  C <- rbind(ones, mu / max(abs(mu)))
  b <- c(1, target / max(abs(mu)))
  w <- eq_min(C, b)
  if (!is.null(w)) frontier_u_weights[k, ] <- w
}
frontier_u_weights <- frontier_u_weights[complete.cases(frontier_u_weights), ,
                                         drop = FALSE]

frontier_table <- function(W, type_label) {
  ret <- as.numeric(W %*% mu)
  vol <- sqrt(rowSums((W %*% S) * W))
  data.frame(
    Type = type_label,
    RetDaily = ret,
    VolDaily = vol,
    SharpeAnnual = ((ret - rf_mean) / vol) * sqrt(days),
    RetAnnualPct = ret * days * 100,
    VolAnnualPct = vol * sqrt(days) * 100
  )
}
frontier_u <- frontier_table(frontier_u_weights, "Unconstrained")

## 8. Constrained GMV/tangency and frontier --------------------

# Enumerate all active faces: each weight is free, fixed at zero,
# or fixed at the 30% upper bound.
faces <- as.matrix(expand.grid(rep(list(0:2), n_assets)))

bounded_gmv <- function() {
  best_w <- NULL
  best_variance <- Inf

  for (i in seq_len(nrow(faces))) {
    active <- which(faces[i, ] != 0)
    C <- matrix(ones, nrow = 1)
    b <- 1

    if (length(active) > 0) {
      C <- rbind(C, diag(n_assets)[active, , drop = FALSE])
      b <- c(b, ifelse(faces[i, active] == 1, 0, weight_cap))
    }

    w <- eq_min(C, b)
    if (is.null(w)) next
    if (min(w) < -1e-8 || max(w) > weight_cap + 1e-8) next

    v <- port_variance(w)
    if (v < best_variance) {
      best_w <- w
      best_variance <- v
    }
  }

  if (is.null(best_w)) stop("No feasible constrained GMV portfolio found.")
  best_w
}

# Tangency transformation: y = w / ((mu-rf)'w).
# Minimise y'Sy subject to e'y=1, y>=0 and y_i<=cap*sum(y).
bounded_tangency <- function() {
  e <- excess / max(abs(excess))
  best_y <- NULL
  best_variance <- Inf

  for (i in seq_len(nrow(faces))) {
    lower_active <- which(faces[i, ] == 1)
    upper_active <- which(faces[i, ] == 2)

    C <- matrix(e, nrow = 1)
    if (length(lower_active) > 0) {
      C <- rbind(C, diag(n_assets)[lower_active, , drop = FALSE])
    }
    if (length(upper_active) > 0) {
      upper_rows <- diag(n_assets)[upper_active, , drop = FALSE] -
                    weight_cap * matrix(1, nrow = length(upper_active),
                                        ncol = n_assets)
      C <- rbind(C, upper_rows)
    }

    b <- c(1, rep(0, length(lower_active) + length(upper_active)))
    y <- eq_min(C, b)
    if (is.null(y)) next
    if (min(y) < -1e-8 ||
        max(y - weight_cap * sum(y)) > 1e-8) next

    v <- port_variance(y)
    if (v < best_variance) {
      best_y <- y
      best_variance <- v
    }
  }

  if (is.null(best_y) || sum(best_y) <= 0) {
    stop("No feasible constrained tangency portfolio found.")
  }
  w <- best_y / sum(best_y)
  w[abs(w) < 1e-12] <- 0
  w
}

w_gmv_c <- bounded_gmv()
w_tangency_c <- bounded_tangency()

metrics <- rbind(
  metrics_unconstrained,
  make_metrics("GMV_Constrained", w_gmv_c),
  make_metrics("Tangency_Constrained", w_tangency_c),
  data.frame(
    Portfolio = "RiskFree",
    ExpectedReturnDaily = rf_mean,
    VolatilityDaily = 0,
    SharpeDaily = NA_real_,
    ExpectedReturnAnnualPct = rf_annual_pct,
    VolatilityAnnualPct = 0,
    SharpeAnnual = NA_real_
  )
)

weights_out <- data.frame(
  Asset = assets,
  Symbol = symbols,
  GMV_Unconstrained = w_gmv,
  Tangency_Unconstrained = w_tangency,
  GMV_Constrained = w_gmv_c,
  Tangency_Constrained = w_tangency_c
)

# Constrained frontier target range: GMV to the maximum-return feasible
# portfolio under the 30% cap.
max_return_weights <- rep(0, n_assets)
remaining_weight <- 1
for (j in order(mu, decreasing = TRUE)) {
  allocation <- min(weight_cap, remaining_weight)
  max_return_weights[j] <- allocation
  remaining_weight <- remaining_weight - allocation
}

target_constrained <- seq(
  from = port_return(w_gmv_c),
  to = port_return(max_return_weights),
  length.out = 200
)
frontier_c_weights <- matrix(NA_real_, nrow = length(target_constrained),
                             ncol = n_assets)

for (k in seq_along(target_constrained)) {
  target <- target_constrained[k]
  best_w <- NULL
  best_variance <- Inf

  for (i in seq_len(nrow(faces))) {
    active <- which(faces[i, ] != 0)
    C <- rbind(ones, mu / max(abs(mu)))
    b <- c(1, target / max(abs(mu)))

    if (length(active) > 0) {
      C <- rbind(C, diag(n_assets)[active, , drop = FALSE])
      b <- c(b, ifelse(faces[i, active] == 1, 0, weight_cap))
    }

    w <- eq_min(C, b)
    if (is.null(w)) next
    if (min(w) < -1e-8 || max(w) > weight_cap + 1e-8) next

    v <- port_variance(w)
    if (v < best_variance) {
      best_w <- w
      best_variance <- v
    }
  }

  if (!is.null(best_w)) frontier_c_weights[k, ] <- best_w
}

frontier_c_weights <- frontier_c_weights[complete.cases(frontier_c_weights), ,
                                         drop = FALSE]
if (nrow(frontier_c_weights) < 2) {
  stop("The constrained efficient frontier could not be constructed.")
}
frontier_c <- frontier_table(frontier_c_weights, "Constrained")

## 9. CAL, portfolio tables and frontier CSV ------------------

metrics$RiskFreeAnnualPct <- rf_annual_pct
write_output(metrics, "Q1_portfolio_metrics.csv")
write_output(weights_out, "Q1_portfolio_weights.csv")

frontiers_out <- rbind(frontier_u, frontier_c)
write_output(frontiers_out, "Q1_efficient_frontiers.csv")

random_vol_annual <- random_volatility * sqrt(days) * 100
frontier_vol_annual <- c(frontier_u$VolAnnualPct, frontier_c$VolAnnualPct)
x_max <- max(c(random_vol_annual, frontier_vol_annual,
               metrics$VolatilityAnnualPct), na.rm = TRUE) * 1.05
cal_x <- seq(0, x_max, length.out = 300)
tangency_annual_sr <- metrics$SharpeAnnual[
  metrics$Portfolio == "Tangency_Unconstrained"
]
cal <- data.frame(
  VolAnnualPct = cal_x,
  RetAnnualPct = rf_annual_pct + tangency_annual_sr * cal_x
)
write_output(cal, "Q1b_capital_allocation_line.csv")

## 10. Figure 1: common-sample return series -------------------

plot_matrix <- matrix(NA_real_, nrow = length(sample_dates), ncol = 6)
for (j in seq_along(assets)) {
  x <- simple_mat[, j] * 100
  x[!common_sample] <- NA_real_
  plot_matrix[, j] <- x
}
rf_plot <- rf_daily * 100
rf_plot[!common_sample] <- NA_real_
plot_matrix[, 6] <- rf_plot

png(file.path(fig_dir, "Figure1_return_series.png"),
    width = 1800, height = 1900, res = 160, bg = "white")
old_par <- par(no.readonly = TRUE)
par(mfrow = c(6, 1), mar = c(1.7, 4.6, 1.7, 1.0),
    oma = c(2.5, 0, 2.5, 0), family = "sans", las = 1,
    mgp = c(2.7, 0.7, 0))
panel_titles <- c(
  "Gree Electric (000651)",
  "Supor (002032)",
  "Hisense Visual Technology (600060)",
  "Haier Smart Home (600690)",
  "Sichuan Changhong (600839)",
  "3-month Chinese Treasury-bill proxy"
)
for (j in seq_len(6)) {
  y <- plot_matrix[, j]
  plot(sample_dates, y, type = "n",
       xlim = range(sample_dates),
       ylim = range(y, finite = TRUE),
       xlab = "", ylab = "Daily return (%)",
       main = panel_titles[j], cex.main = 0.9)
  abline(h = pretty(y, n = 5), col = "#E8EDF1", lwd = 0.7)
  lines(sample_dates, y,
        col = if (j == 6) "#C46B28" else "#176B87",
        lwd = 0.55)
  if (j == 6) axis.Date(1, at = pretty(sample_dates, n = 8), format = "%Y")
}
mtext(
  sprintf("Figure 1. Daily simple returns on the %s-date common sample (2010-2024)",
          format(common_n, big.mark = ",")),
  side = 3, outer = TRUE, font = 2, cex = 1.15
)
par(old_par)
dev.off()

## 11. Figure 2: unconstrained frontier, random portfolios and CAL

random_ret_annual <- random_return * days * 100
frontier_u_x <- frontier_u$VolAnnualPct
frontier_u_y <- frontier_u$RetAnnualPct

png(file.path(fig_dir, "Figure2_frontier_CAL.png"),
    width = 2300, height = 1300, res = 180, bg = "white")
par(oma = c(0, 0, 2.5, 0))
layout(matrix(c(1, 2), nrow = 1), widths = c(1.05, 1))
par(mar = c(4.5, 4.8, 2.2, 1), family = "sans", las = 1)

# Keep the original 10,000 portfolios and all numerical outputs.
# Show the full distribution beside a focused view of the efficient frontier.
plot_unconstrained <- function(x_range, y_range, panel_title) {
  plot(random_vol_annual, random_ret_annual,
       pch = 16, cex = 0.35, col = adjustcolor("#176B87", 0.28),
       xlim = x_range, ylim = y_range,
       xlab = "Annualised volatility (%)",
       ylab = "Annualised expected return (%)", main = panel_title)
  grid(col = "#E8EDF1")
  lines(frontier_u$VolAnnualPct, frontier_u$RetAnnualPct,
        col = "#176B87", lwd = 2.4)
  lines(cal$VolAnnualPct, cal$RetAnnualPct,
        col = "#C46B28", lty = 2, lwd = 2)
  points(metrics$VolatilityAnnualPct[1], metrics$ExpectedReturnAnnualPct[1],
         pch = 24, col = "#203449", bg = "#176B87", cex = 1.5)
  points(metrics$VolatilityAnnualPct[2], metrics$ExpectedReturnAnnualPct[2],
         pch = 23, col = "#203449", bg = "#E2B54B", cex = 1.5)
  points(0, rf_annual_pct, pch = 21, col = "#39754C", bg = "#39754C", cex = 1.2)
}
full_y <- range(c(random_ret_annual, frontier_u_y, cal$RetAnnualPct,
                  metrics$ExpectedReturnAnnualPct), finite = TRUE)
full_x <- c(0, max(c(random_vol_annual, frontier_u_x, cal$VolAnnualPct),
                  finite = TRUE) * 1.02)
plot_unconstrained(full_x, full_y, "(a) All 10,000 random portfolios")
legend("topleft",
       c("Efficient frontier", "CAL", "Random portfolios", "GMV", "Tangency", "Risk-free"),
       col = c("#176B87", "#C46B28", "#6D9E98", "#203449", "#203449", "#39754C"),
       lty = c(1, 2, NA, NA, NA, NA), pch = c(NA, NA, 16, 24, 23, 21),
       pt.bg = c(NA, NA, NA, "#176B87", "#E2B54B", "#39754C"),
       bty = "n", cex = 0.72)

detail_x <- range(c(frontier_u_x, metrics$VolatilityAnnualPct[1:2]))
detail_y <- range(c(frontier_u_y, metrics$ExpectedReturnAnnualPct[1:2]))
detail_x <- detail_x + c(-0.15, 0.20)
detail_y <- detail_y + c(-0.40, 0.40)
plot_unconstrained(detail_x, detail_y, "(b) Detail around GMV and tangency")
text(metrics$VolatilityAnnualPct[1], metrics$ExpectedReturnAnnualPct[1],
     "GMV", pos = 4, offset = 0.6, cex = 0.8)
text(metrics$VolatilityAnnualPct[2], metrics$ExpectedReturnAnnualPct[2],
     "Tangency", pos = 4, offset = 0.6, cex = 0.8)
mtext("Figure 2. Unconstrained efficient frontier and capital allocation line",
      side = 3, outer = TRUE, font = 2, cex = 1.1)
dev.off()

## 12. Figure 3: constrained vs unconstrained frontiers ---------

all_frontier_x <- c(frontier_u$VolAnnualPct, frontier_c$VolAnnualPct,
                    metrics$VolatilityAnnualPct[1:4])
all_frontier_y <- c(frontier_u$RetAnnualPct, frontier_c$RetAnnualPct,
                    metrics$ExpectedReturnAnnualPct[1:4])

plot_frontier_comparison <- function(xlim, ylim, title_text) {
  plot(NA, xlim = xlim, ylim = ylim,
       xlab = "Annualised volatility (%)",
       ylab = "Annualised expected return (%)",
       main = title_text)
  grid(col = "#E8EDF1")
  # Correct coordinate order for both frontiers: x = volatility, y = return.
  lines(frontier_u$VolAnnualPct, frontier_u$RetAnnualPct,
        col = "#176B87", lwd = 2.3)
  lines(frontier_c$VolAnnualPct, frontier_c$RetAnnualPct,
        col = "#C46B28", lty = 2, lwd = 2.3)
  points(metrics$VolatilityAnnualPct[1], metrics$ExpectedReturnAnnualPct[1],
         pch = 21, col = "#203449", bg = "#176B87", cex = 1.35)
  points(metrics$VolatilityAnnualPct[2], metrics$ExpectedReturnAnnualPct[2],
         pch = 23, col = "#203449", bg = "#E2B54B", cex = 1.3)
  points(metrics$VolatilityAnnualPct[4], metrics$ExpectedReturnAnnualPct[4],
         pch = 24, col = "#203449", bg = "#C46B28", cex = 1.3)
}

png(file.path(fig_dir, "Figure3_constrained_frontiers.png"),
    width = 2300, height = 1250, res = 180, bg = "white")
par(oma = c(0, 0, 2.5, 0))
layout(matrix(c(1, 2), nrow = 1), widths = c(1.15, 1))
par(mar = c(4.5, 4.8, 2.3, 1), family = "sans", las = 1)
x_pad <- max(diff(range(all_frontier_x, finite = TRUE)) * 0.04, 0.15)
y_pad <- max(diff(range(all_frontier_y, finite = TRUE)) * 0.06, 0.10)
plot_frontier_comparison(
  range(all_frontier_x, finite = TRUE) + c(-x_pad, x_pad),
  range(all_frontier_y, finite = TRUE) + c(-y_pad, y_pad),
  "(a) Full frontier comparison"
)

zoom_x <- range(c(frontier_c$VolAnnualPct,
                  metrics$VolatilityAnnualPct[c(1, 2, 4)]), finite = TRUE)
zoom_y <- range(c(frontier_c$RetAnnualPct,
                  metrics$ExpectedReturnAnnualPct[c(1, 2, 4)]), finite = TRUE)
zoom_x_pad <- max(diff(zoom_x) * 0.18, 0.12)
zoom_y_pad <- max(diff(zoom_y) * 0.18, 0.08)
plot_frontier_comparison(
  zoom_x + c(-zoom_x_pad, zoom_x_pad),
  zoom_y + c(-zoom_y_pad, zoom_y_pad),
  "(b) Detail around the constrained frontier"
)
mtext("Figure 3. Constrained versus unconstrained efficient frontiers",
      side = 3, outer = TRUE, font = 2, cex = 1.15)
legend("bottomright",
       c("Unconstrained frontier", "Constrained frontier (0 <= wi <= 0.30)",
         "GMV", "Unconstrained tangency", "Constrained tangency"),
       col = c("#176B87", "#C46B28", "#203449", "#203449", "#203449"),
       lty = c(1, 2, NA, NA, NA),
       pch = c(NA, NA, 21, 23, 24),
       pt.bg = c(NA, NA, "#176B87", "#E2B54B", "#C46B28"),
       bty = "n", cex = 0.78)
dev.off()

## 13. Numerical self-checks and session information -----------

check_values <- c(
  weights_sum_to_one = max(abs(colSums(
    as.matrix(weights_out[, c("GMV_Unconstrained", "Tangency_Unconstrained",
                              "GMV_Constrained", "Tangency_Constrained")])
  ) - 1)) < 1e-8,
  constrained_weights_within_bounds =
    min(c(w_gmv_c, w_tangency_c)) >= -1e-8 &&
    max(c(w_gmv_c, w_tangency_c)) <= weight_cap + 1e-8,
  gmv_unchanged_when_unconstrained_gmv_is_feasible =
    max(abs(w_gmv_c - w_gmv)) < 1e-7,
  constrained_tangency_sharpe_not_higher =
    port_sharpe(w_tangency_c) <= port_sharpe(w_tangency) + 1e-8,
  cal_passes_through_tangency =
    abs(
      rf_annual_pct +
        tangency_annual_sr * metrics$VolatilityAnnualPct[2] -
        metrics$ExpectedReturnAnnualPct[2]
    ) < 1e-7,
  all_frontier_weights_fully_invested =
    max(abs(rowSums(frontier_u_weights) - 1)) < 1e-7 &&
    max(abs(rowSums(frontier_c_weights) - 1)) < 1e-7,
  full_data_output_has_all_market_dates = nrow(full_output) == length(sample_dates),
  rf_quotes_precede_return_dates = all(rf_quote_date < sample_dates),
  common_sample_meets_observation_requirement = common_n >= 2520,
  common_sample_covers_at_least_15_calendar_years = sample_years >= 15,
  random_portfolio_count_is_10000 = nrow(random_portfolios) == 10000
)

checks <- data.frame(
  Check = names(check_values),
  Passed = as.logical(check_values),
  stringsAsFactors = FALSE
)
checks$Detail <- c(
  "All four portfolio weight vectors sum to one.",
  "Constrained portfolio weights satisfy 0 <= wi <= 0.30.",
  "The unconstrained GMV already satisfies the imposed bounds.",
  "The constrained tangency Sharpe ratio does not exceed the unconstrained one.",
  "The CAL passes through the unconstrained tangency portfolio.",
  "All retained frontier points are fully invested.",
  paste("Full output dates:", nrow(full_output)),
  "Every risk-free quote date is strictly earlier than its return date.",
  paste("Common sample observations:", common_n),
  paste("Calendar-year coverage:", sample_years),
  "Exactly 10,000 random portfolios are generated and exported."
)
write_output(checks, "Q1_self_checks.csv")

cat("\n================ FIN305 Q1 RUN SUMMARY ================\n")
cat("Sample dates:", as.character(min(sample_dates)), "to",
    as.character(max(sample_dates)), "\n")
cat("All market trading dates exported:", nrow(full_output), "\n")
cat("Common-sample observations:", common_n, "\n")
cat("Adjacent common-sample pairs used for AC1:", length(adjacent_pair_index), "\n")
cat("Annualised risk-free rate (%):", round(rf_annual_pct, 6), "\n\n")
print(metrics, row.names = FALSE, digits = 6)
cat("\nPortfolio weights:\n")
print(weights_out, row.names = FALSE, digits = 6)
cat("\nSelf-checks:\n")
print(checks, row.names = FALSE)
if (!all(checks$Passed)) {
  stop("At least one numerical self-check failed. See CSV/Q1_self_checks.csv.")
}

capture.output(sessionInfo(), file = file.path(out_dir, "sessionInfo.txt"))
cat("\nAll Q1 outputs were written to:\n", out_dir, "\n")
cat("R session information saved to sessionInfo.txt\n")
cat("========================================================\n")
