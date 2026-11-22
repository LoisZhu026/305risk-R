# Inputs and original exports

All current inputs, original exports and the daily hand-off are included in this
repository. Clone/download the complete repository, open `305risk-R.Rproj`, and
Source `R/FIN305_Q1_complete.R`. Normal analysis does not require Python or a
separate ZIP from another group member.

## Current inputs

| Input | Preserved fields and coverage | Used by |
|---|---|---|
| `data/csmar_adjusted_long.csv` | Original back-adjusted prices, stock codes, trading/filling flags and source-archive names; 2009-12-31 to 2024-12-31 | Q1; stock returns for Q2/Q3 |
| `data/trading_calendar.csv` | Ordered market sessions, including 2009-12-31 as the first-return baseline | Q1; date and gap checks in Q2/Q3 |
| `data/treasury_3m_quotes.csv` | ChinaBond quote dates and original annual yields in percent; 2009-12-31 to 2024-12-31 | Q1; shared risk-free convention |
| `data/csi300_close.csv` | CSI 300 price-index dates, code, name and closing points; 2008-12-01 to 2024-12-31 | Q3(b) |

`input_manifest.csv` records each input's row count, coverage and SHA-256 digest.
The three Q1 input CSVs and the CSI 300 CSV retain the audited values. Returns,
eligibility, the common sample, risk-free conversion and portfolio analysis are
calculated by the current R script.

## Original files retained here

| Location under `preparation/` | Contents and purpose |
|---|---|
| `CSMAR_stock_originalsource/adjusted/` | Five original back-adjusted export ZIPs; each export's Excel table is also exposed under its numeric batch-ID folder |
| `CSMAR_stock_originalsource/raw/` | Five original unadjusted export ZIPs; each Excel table is also exposed under its numeric batch-ID folder |
| `CSMAR_stock_originalsource/版权声明.pdf` | Unchanged copyright document supplied in every CSMAR ZIP |
| `CSMAR_stock_originalsource/*/字段说明.txt` | Unchanged provider field descriptions for adjusted/unadjusted tables |
| `ChinaBond_original/` | Original ChinaBond ZIP and its sixteen Excel exports as individual files |
| `csmar_raw_long.csv` | Combined original unadjusted quotes for tracing and cross-checking source IDs; not the return input used by Q1 |
| `input_inventory.csv` | Ten CSMAR batches, row counts and date coverage |
| `source_audit.json` | Source deduplication, key/calendar reconciliation and original archive checksums |

The original ZIPs are preserved byte-for-byte. The individually exposed Excel
files match the corresponding ZIP members byte-for-byte. The ZIPs are the source
for optional rebuilding; individual tables can be inspected without unpacking.

## Optional source verification and rebuilding

Only this step requires Python 3.10+ and `openpyxl`:

```sh
python3 -m pip install openpyxl
python3 preparation/prepare_inputs.py --check
```

The check reads the included original archives, rejects conflicting overlaps,
reconstructs the market calendar and compares the source tables with the current
CSV inputs. It also checks all four input checksums, including the CSI 300 file.

To rebuild the source tables, use `--rebuild` instead of `--check`, then rerun the
R analysis. The preparation script writes the three Q1 input CSVs, the combined
unadjusted-price CSV, the batch inventory and the source audit; it updates input
checksums. The CSI 300 CSV is retained from the original official download.
This preparation script does not calculate returns, portfolios, VaR or GARCH.

Source reconciliation: 23,490 adjusted export rows become 19,570 unique rows
after 3,920 identical overlaps are removed; there are no conflicting overlaps.
The unadjusted exports contain 17,886 rows. The calendar has 3,644 market sessions
including the 2009-12-31 baseline; the R analysis uses 3,643 market dates and
retains 3,258 common-return dates under the agreed suspension policy.

## Provider sources and units

- **CSMAR:** `ClosePrice` in the back-adjusted export is already adjusted. Do not
  apply a second adjustment. `Filling`/`StateCode` distinguish observed trading
  quotes from filled prices and holidays. `Distance` is retained as a source field
  and is not used as a market-session counter.
- **ChinaBond:** [government bond yield curve, historical data](https://yield.chinabond.com.cn/cbweb-cbrc-web/cbrc/showHistory?locale=cn_ZH&mark=1),
  3-month tenor. `AnnualYieldPct = 2` means 2% per year. R uses the latest quote
  strictly before each return date and converts it by `(1+y/100)^(1/252)-1`.
- **CSI:** [official historical price-index endpoint](https://www.csindex.com.cn/csindex-home/perf/index-perf?indexCode=000300&startDate=20081201&endDate=20241231).
  CSV fields map from `tradeDate`, `indexCode`, `indexNameCnAll` and `close`.
  Read `IndexCode` as text (`000300`); `IndexClose` is measured in index points.
  This is a price index. The December 2008 start supports January 2010's trailing
  12-month regime classification without future information.

## Industry evidence

Use **2024 year-end Shenwan Level 1: Household Appliances** for all five stocks.
The five companies appear on page 5 of the
[Wanlian Securities industry report](https://pdf.dfcfw.com/pdf/H3_AP202502101642936576_1.pdf#page=5).
Their narrower product businesses differ.

## Superseded material

The earlier `analysis.R`, old Q1 packages, generated report drafts, Python-return
tables (`stock_inputs_returns.csv`, `returns_complete_cases.csv`) and pre-aligned
risk-free table are superseded by the current R script and its outputs. They are
kept in the original local archive and are not included as competing versions in
this repository.
