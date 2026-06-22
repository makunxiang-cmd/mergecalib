# mergecalib

<!-- badges: start -->
[![R-CMD-check](https://github.com/makunxiang-cmd/mergecalib/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/makunxiang-cmd/mergecalib/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

`mergecalib` is an R package for **within-province cell merging and
proportion-interval calibration**. The input is organised by demographic cell;
each row contains:

- province, sex, urban/rural, age group, and education level;
- a sample size and the total survey weight of the cell;
- the counts of four outcome grades A, B, C, and D.

The package uses a deterministic set of candidate merge clusters and a
set-partitioning mixed-integer linear program (MILP) to find a complete
within-province merge plan such that:

1. every original cell belongs to exactly one final merged cluster;
2. every final merged cluster has a strictly positive sample size;
3. each province's weighted ABCD proportions fall inside the target intervals;
4. specified national populations' weighted ABCD proportions fall inside the
   target intervals;
5. once the targets are met, the merged sample size, demographic distance,
   outcome heterogeneity, weight distortion, and merge count are minimised
   lexicographically.

## The key zero-sample guarantee

- An original cell with `n = 0` is **never** allowed to stand as its own
  candidate cluster.
- Every zero-sample cell must be merged with at least one `n > 0` cell in the
  same province.
- Each province is given a deterministic "zero-sample absorption partition".
- After solving, `audit_merge_fit()` re-checks that `final_n > 0`.
- If an entire province consists of `n = 0` cells, the package reports a
  structural infeasibility and produces no pseudo-result.
- If a target population has zero total observed sample, the package likewise
  reports that it is not estimable, because merging never creates observations
  for that population.

## Disclaimer

`mergecalib` is a statistical computation tool; the merge plans it produces must
be reviewed by a qualified statistician before use. In an interactive session
you will be asked to accept a short disclaimer before the first model is fitted.
You can read it at any time with `mergecalib_disclaimer()` and acknowledge it
with `mergecalib_agree(TRUE)`.

## Installation

Install the HiGHS solver interface first:

```r
install.packages("highs")
```

Then install mergecalib from the local source package:

```r
install.packages("mergecalib_0.1.0.tar.gz", repos = NULL, type = "source")
```

or from a checked-out source directory:

```r
install.packages("/path/to/mergecalib", repos = NULL, type = "source")
```

You can also install directly from GitHub:

```r
# install.packages("remotes")
remotes::install_github("makunxiang-cmd/mergecalib")
```

## Project documentation

Maintainer-facing documentation lives under
[`../docs/maintainer/`](../docs/maintainer/):

- [`../docs/maintainer/PROJECT_OVERVIEW.md`](../docs/maintainer/PROJECT_OVERVIEW.md)
  explains the package architecture, solver flow, outputs, and invariants.
- [`../docs/maintainer/DEVELOPMENT.md`](../docs/maintainer/DEVELOPMENT.md)
  covers local setup, testing, documentation, CRAN checks, and repository
  hygiene.
- [`../docs/maintainer/ROADMAP_v0.2.0.md`](../docs/maintainer/ROADMAP_v0.2.0.md)
  tracks the planned v0.2.0 workstreams.

The root [`../AGENTS.md`](../AGENTS.md) is the handoff file for AI agents and
new maintainers.

## Quick example

```r
library(mergecalib)
mergecalib_agree(TRUE)  # acknowledge the disclaimer for this session

spec <- merge_spec(
  level_orders = list(
    age = c("18-39", "40+"),
    education = c("low", "high")
  )
)

dat <- example_merge_data()
targets <- example_merge_targets(dat, spec)

fit <- fit_merge_calibration(
  data = dat,
  targets = targets,
  spec = spec
)

fit
summary(fit)
```

## Input data

The default fields are:

| Field | Meaning |
|---|---|
| `cell_id` | Unique identifier of the original demographic cell |
| `province` | Province |
| `sex` | Sex |
| `urban` | Urban/rural |
| `age` | Age group |
| `education` | Education level |
| `n` | Sample size |
| `weight` | Total survey weight of the original cell |
| `A`, `B`, `C`, `D` | Counts of the four grades; their sum must equal `n` |

If your field names differ, map them through `merge_spec()`:

```r
spec <- merge_spec(
  province = "prov",
  id = "cell",
  n = "sample",
  weight = "wsum",
  grades = c(A = "gA", B = "gB", C = "gC", D = "gD"),
  groups = c(
    sex = "sex",
    urban = "urban",
    age = "age_band",
    education = "edu"
  ),
  ordered_groups = c("age", "education"),
  level_orders = list(
    age = c("18-29", "30-39", "40-49", "50-59", "60+"),
    education = c("primary", "junior", "senior", "college", "bachelor+")
  )
)
```

## Target table

Each row of the target table controls one grade and must contain:

- `target_id`
- `grade`
- `lower`
- `upper`

Province and demographic variables use concrete values to express a filter, and
`NA` or `"*"` to express a wildcard.

```r
targets <- data.frame(
  target_id = c("beijing", "beijing", "national_male", "national_male"),
  grade = c("A", "B", "A", "B"),
  lower = c(0.25, 0.25, 0.24, 0.26),
  upper = c(0.30, 0.31, 0.29, 0.32),
  province = c("beijing", "beijing", NA, NA),
  sex = c(NA, NA, "M", "M"),
  urban = NA,
  age = NA,
  education = NA,
  stringsAsFactors = FALSE
)
```

You can control marginal and cross-classified populations at the same time. For
a national "male x urban x 18-29 x bachelor+" population, just set those four
fields to concrete values simultaneously.

## Main outputs

```r
cell_map(fit)               # mapping from original cells to final clusters
merge_plan(fit)             # step-by-step merge operations, smallest cells first
final_cells(fit)            # final clusters; final_n is guaranteed positive
target_results(fit)         # initial value, final value, and interval status
province_results(fit)       # ABCD results for every province
national_cell_results(fit)  # national non-zero-sample fine-cell results
audit_merge_fit(fit)        # full audit
export_merge_results(fit, "result_dir")  # export all CSVs and the fit object
```

Summaries over arbitrary dimensions:

```r
calculate_results(fit, by = c("sex"))
calculate_results(fit, by = c("sex", "urban"))
calculate_results(fit, by = c("age", "education"))
```

## When targets are infeasible

If the strict targets are infeasible, the package searches for the minimum
uniform relaxation `delta` by default:

```r
fit$delta
```

The effective interval is:

```text
[max(0, lower - delta), min(1, upper + delta)]
```

Relaxation can be disabled:

```r
fit_merge_calibration(dat, targets, spec, relax_targets = FALSE)
```

or capped:

```r
fit_merge_calibration(dat, targets, spec, max_delta = 0.03)
```

## Reproducibility

The defaults use fixed ordering, single-threaded HiGHS, a fixed random seed,
parallel branching off, fixed candidate-expansion levels, and lexicographic
(rather than randomly weighted) objectives. Identical inputs therefore yield
identical results under the same package version.

## Scope

The package only allows **within-province merging**. If a province has zero
total sample, or a target population has no observed sample anywhere in the
country, the problem has no feasible mathematical solution under the current
rules. The package reports this explicitly rather than substituting another
province, a national mean, or fabricated sample.
