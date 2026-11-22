# 305risk-R
Risk Management group project (R): mean–variance portfolio analysis of five Chinese household-appliance stocks (2010–2024), Gaussian-copula VaR with expanding-window backtesting, and GARCH(1,1) volatility across market regimes.

## Running the project

This repository is public. Obtain the group-only input package and copy its four
CSV inputs into `data/` before running. Source data and daily return files are
excluded from Git; see [input preparation and sources](prep/DATA_PREPARATION.md).

1. Double-click `305risk-R.Rproj` to open the project in RStudio. This sets the
   project working directory; the project file itself does not run calculations.
2. Open `R/FIN305_Q1_complete.R` and click **Source** (base R only).
3. Check `CSV/Q1_self_checks.csv`: all 11 checks should be `TRUE`.
4. To regenerate the separate development hand-off, run
   `Rscript handoff/make_handoff.R` from the project directory. An absolute path
   to either R script also works from outside the project.

## Scope

| Question | Content | Weight |
|---|---|---|
| Q1 | Returns and descriptive statistics; efficient frontier, GMV, tangency portfolio, CAL; portfolios with a 30% weight cap | 30% |
| Q2 | Gaussian copula; three 1-day 95% VaR estimates; expanding-window 90% VaR backtest | 40% |
| Q3 | GARCH(1,1) for GMV and tangency portfolios; up- vs down-market regimes; GARCH-based VaR | 30% |

## Repository structure

    305risk-R/
    ├── 305risk-R.Rproj
    ├── R/
    │   └── FIN305_Q1_complete.R   Main submission script. Q2 and Q3 are appended to it.
    ├── data/                      Group-only CSV inputs; GitHub tracks only a placeholder
    │   ├── csmar_adjusted_long.csv Five-stock adjusted prices and trading/filling flags
    │   ├── trading_calendar.csv   Full market-session calendar
    │   ├── treasury_3m_quotes.csv ChinaBond original 3-month annual yield quotes
    │   └── csi300_close.csv       CSI 300 price-index daily closes for Q3
    ├── prep/                      Source/preparation notes and input checksums
    ├── handoff/                   Q1 output prepared for Q2/Q3, and the R script that creates it
    ├── CSV/                       Result tables for all questions (Q1..., Q2..., Q3...)
    └── Figures/                   Figures written by the main script

`prep/` contains preparation notes and input checksums, not the source datasets.
The group package includes the four CSVs under `data/`; original CSMAR ZIPs and
ChinaBond Excel exports remain in the existing source archive described in
`prep/DATA_PREPARATION.md`.

`data/` holds analysis inputs; `CSV/` holds calculated table outputs for Q1, Q2
and Q3, with question-prefixed filenames to keep them distinct. Q1 reads the
stock-price, calendar and Treasury-quote inputs; the CSI 300 input is for Q3.
`handoff/` separately holds the Q1 results prepared for Q2/Q3 development.

## Data

| Data | Source | File |
|---|---|---|
| Daily back-adjusted closing prices and trading status | CSMAR | data/csmar_adjusted_long.csv |
| Full market trading calendar, including the first-return baseline | CSMAR trading-state fields | data/trading_calendar.csv |
| Risk-free rate | ChinaBond government bond yield curve, 3-month tenor | data/treasury_3m_quotes.csv |
| Market index (Q3) | China Securities Index Co. (CSI), official historical data: CSI 300 price index (000300), daily close, 1 Dec 2008 – 31 Dec 2024 | data/csi300_close.csv |

Stocks (Shenwan Level 1: Household Appliances): 000651 Gree Electric, 002032 Supor,
600060 Hisense Visual Technology, 600690 Haier Smart Home, 600839 Sichuan Changhong.

The CSI 300 series starts in December 2008 so that the 12-month market return
used to classify regimes in Q3(b) is available from January 2010.

## Q1 key results

| Portfolio | Annual return | Annual volatility | Annual Sharpe |
|---|---|---|---|
| GMV (unconstrained) | 18.83% | 26.67% | 0.6176 |
| Tangency (unconstrained) | 20.35% | 27.87% | 0.6454 |
| Tangency (0 ≤ w ≤ 30%) | 19.37% | 26.89% | 0.6325 |

Annualised risk-free rate: 2.364%. The constrained GMV equals the unconstrained GMV.

## Hand-off for Q2 and Q3

| File under `handoff/` | Purpose | Availability |
|---|---|---|
| `Q1_Q2_Q3_handoff.csv` | Written conventions/receipt checklist; Q2/Q3 owners confirm the relevant rows | Public repository |
| `Q2_Q3_handoff.csv` | R-generated daily data from Q1: five stock returns, risk-free inputs, portfolio returns and date gaps | Group package only |
| `make_handoff.R` | Runs the main Q1 script and exports the daily hand-off CSV | Public repository |

The daily hand-off lets Q2/Q3 reuse the actual Q1 results without rebuilding
returns. It is a development aid; in the final submission, Q2/Q3 code uses the
Q1 objects (`R`, `w_gmv`, `w_tangency`, `rf_common`, `common_dates`,
`common_sessions`) directly. The columns below refer to the daily hand-off CSV.

| Column | Meaning |
|---|---|
| ObsIndex | Observation number, 1–3258 |
| Date | Trading date |
| SessionIndex | Position in the full market trading calendar |
| SessionGapFromPreviousObs | Trading sessions since the previous row (1 = adjacent) |
| r_000651 … r_600839 | Daily simple returns of the five stocks |
| RfQuoteDate / RfAnnualYieldPct | Source quote date and original annual yield in percent |
| RfDailyReturn | Daily risk-free return |
| GMV_Unconstrained | Daily return of the unconstrained GMV portfolio (Q3) |
| Tangency_Unconstrained | Daily return of the unconstrained tangency portfolio (Q2, Q3) |

Portfolio weights are in `CSV/Q1_portfolio_weights.csv`.

## Attention: conventions used throughout

- **Return eligibility.** A daily return is computed only when the stock trades
  normally on both the current and the previous market session. Returns on
  suspension days and the first return after a suspension (which spans the halt)
  are excluded.
- **Common sample.** Only dates on which all five stocks have a valid return are
  used: 3,258 of 3,643 trading days (4 Jan 2010 – 31 Dec 2024). The excluded days
  include suspensions, first post-suspension returns and the common-sample filter;
  do not describe them all as "suspension days".
- **Date gaps.** 58 pairs of consecutive rows in the common sample are not adjacent
  market sessions. Keep `SessionGapFromPreviousObs`; Q2/Q3 must document the model
  observation step and forecast-date mapping in the report.
- **Returns.** Simple returns in decimals (0.01 = 1%). Log returns are reported in
  Q1(a) only.
- **Risk-free rate.** Daily rate = (1 + annual yield / 100)^(1/252) − 1, using the
  latest quote strictly before each return date. Portfolio analysis uses its
  sample mean.
- **Annualisation.** Mean × 252; volatility × √252; Sharpe ratio × √252.
- **Descriptive statistics.** Standard deviation uses n − 1. Skewness and kurtosis
  use population central moments; kurtosis is reported both raw (normal = 3) and
  excess. AC1 pairs only adjacent market sessions (3,199 pairs).
- **Weights.** Estimated once on the full common sample and kept fixed in Q2 and Q3
  (as the task sheet requires). Do not re-estimate them.
- **Q2(c) split (required by the task sheet).** Initial estimation sample =
  rows 1–1000 of the hand-off file (to 16 Jul 2014); forecasts start at row 1001
  (17 Jul 2014), 2,258 forecasts in total.
- **Asset order.** Always 000651, 002032, 600060, 600690, 600839.
- **Source of results.** Every number, table and figure in the report must come
  from the R scripts in this repository.
