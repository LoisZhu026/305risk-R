# Inputs and preparation

The public repository contains code and aggregate results. Source data and daily
returns are shared separately within the group. Copy the four CSVs from the group
package into `data/`; keep their names unchanged. `input_manifest.csv` records
their source, coverage, row count and SHA-256 digest.

| Input | What it preserves | Used by |
|---|---|---|
| `data/csmar_adjusted_long.csv` | CSMAR back-adjusted closing prices, six-digit stock codes, trading/filling flags and source-archive names | Q1; returns for Q2/Q3 |
| `data/trading_calendar.csv` | Ordered market sessions, including 2009-12-31 as the first-return baseline | Q1; date and gap checks in Q2/Q3 |
| `data/treasury_3m_quotes.csv` | ChinaBond quote dates and original annual yields in percent | Q1; common risk-free convention |
| `data/csi300_close.csv` | CSI 300 price index: Date, IndexCode, IndexName, IndexClose; close measured in index points | Q3(b) |

## Traceability

- The CSMAR file combines five back-adjusted quotation exports, retains the original
  values and status flags, deduplicates identical overlapping rows, and records the
  contributing ZIPs in `SourceArchives`. The ten original adjusted/unadjusted ZIPs
  remain in the existing group archive under `CSMAR_stock_originalsource/`.
- The calendar uses explicit market-session/trading-state information from the
  exports. `SessionIndex` is a market-session counter; CSMAR's `Distance` field is
  retained but is not used as that counter.
- The ChinaBond file combines annual downloads of the
  [government bond yield curve, 3-month tenor](https://yield.chinabond.com.cn/cbweb-cbrc-web/cbrc/showHistory?locale=cn_ZH&mark=1).
  `AnnualYieldPct = 2` means 2% per year. The original Excel downloads remain in
  the group's ChinaBond ZIP.
- The CSI 300 file uses the index provider's
  [historical price-index endpoint](https://www.csindex.com.cn/csindex-home/perf/index-perf?indexCode=000300&startDate=20081201&endDate=20241231).
  `IndexCode` must be read as text (`000300`); this is a price index, not an ETF or
  a total-return index. The December 2008 start permits the January 2010 regime
  label to use the preceding 12 months without future information.

The source CSVs in this repository's group package are byte-for-byte copies of
the audited inputs. No new Python financial-calculation step is introduced.
`R/FIN305_Q1_complete.R` constructs returns, eligibility, the common sample and
the lagged daily risk-free rate in R. It then performs all Q1 calculations.
The previous preparation script and old reports remain in the original archive;
they are not needed to run this project.

## Industry evidence

Use **2024 year-end Shenwan Level 1: Household Appliances** for all five stocks.
The five names appear on page 5 of the
[Wanlian Securities industry report](https://pdf.dfcfw.com/pdf/H3_AP202502101642936576_1.pdf#page=5).
Do not describe the five companies as belonging to one narrower sub-industry.

## Public versus group-only files

Public: scripts, this preparation note, the input manifest, the conventions table,
portfolio weights, aggregate statistics, frontier/CAL tables and figures.

Group-only: `data/*.csv`, `data/raw/`, `CSV/Q1_returns_and_prices.csv`,
`CSV/Q1b_random_10000_portfolios.csv`, `handoff/Q2_Q3_handoff.csv`, reports and ZIPs.
These paths are excluded by `.gitignore`; never force-add them to the public repo.
