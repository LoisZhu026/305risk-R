# 305risk-R
Risk Management group project (R): mean–variance portfolio analysis of five Chinese household-appliance stocks (2010–2024), Gaussian-copula VaR with expanding-window backtesting, and GARCH(1,1) volatility across market regimes.

## Scope

| Question | Content | Weight |
|---|---|---|
| Q1 | Returns and descriptive statistics; efficient frontier, GMV, tangency portfolio, CAL; portfolios with a 30% weight cap | 30% |
| Q2 | Gaussian copula; three 1-day 95% VaR estimates; expanding-window 90% VaR backtest | 40% |
| Q3 | GARCH(1,1) for GMV and tangency portfolios; up- vs down-market regimes; GARCH-based VaR | 30% |

## Repository structure

    305risk-r/
    ├── 305risk-R.Rproj
    ├── R/
    │   └── FIN305_Q1_complete.R   Main submission script. Q2 and Q3 are appended to it.
    ├── data/                      CSV inputs read by the main script
    │   └── raw/                   Original CSMAR and ChinaBond exports (not tracked)
    ├── prep/                      How the raw exports were combined into data/ (no calculations)
    ├── handoff/                   Q1 output prepared for Q2/Q3, and the R script that creates it
    ├── CSV/                       Result tables written by the main script
    └── Figures/                   Figures written by the main script

## Data

| Data | Source | File |
|---|---|---|
| Daily back-adjusted closing prices and trading status | CSMAR | data/csmar_adjusted_long.csv |
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

`handoff/Q2_Q3_handoff.csv` contains everything Q2 and Q3 need from Q1, so that
nobody has to rebuild returns or portfolio returns on their own. It is created by
`handoff/make_handoff.R`, which runs the main script and exports its results.
It is a working file for development only; in the final submission, Q2 and Q3 code
uses the Q1 objects (`R`, `w_gmv`, `w_tangency`, `rf_common`, `common_dates`,
`common_sessions`) directly.

| Column | Meaning |
|---|---|
| ObsIndex | Observation number, 1–3258 |
| Date | Trading date |
| SessionIndex | Position in the full market trading calendar |
| SessionGapFromPreviousObs | Trading sessions since the previous row (1 = adjacent) |
| r_000651 … r_600839 | Daily simple returns of the five stocks |
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
- **Date gaps.** 58 consecutive rows in the common sample are not adjacent market
  sessions (mainly Gree's 2016–17 suspension). Time-series methods treat rows as
  consecutive; keep `SessionGapFromPreviousObs` and mention this in the report.
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
- **Q2(c) split (to be confirmed in Q2).** Proposed: initial estimation sample =
  rows 1–1000 of the hand-off file (to 16 Jul 2014); forecasts start at row 1001
  (17 Jul 2014), 2,258 forecasts in total.
- **Asset order.** Always 000651, 002032, 600060, 600690, 600839.
- **Source of results.** Every number, table and figure in the report must come
  from the R scripts in this repository.
