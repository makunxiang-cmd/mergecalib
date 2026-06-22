# mergecalib Project Overview

`mergecalib` is an R package for deterministic within-province cell merging and
proportion-interval calibration.

It starts from demographic cell data. Each row represents one province by
demographic cell with a sample size, total survey weight, and outcome-grade
counts. The package builds a complete merge plan so that every original cell is
assigned to exactly one final cluster, every final cluster has positive sample
size, and provincial or national target proportions can be kept inside
user-supplied intervals when the candidate set makes that feasible.

## Core Guarantees

The project is built around five guarantees:

1. Final clusters must have strictly positive sample size.
2. Zero-sample cells are absorbed only within their own province.
3. The package does not fabricate observations or borrow sample across
   provinces by default.
4. Identical inputs and package version should produce identical outputs.
5. Sample size, total weight, and grade counts are conserved.

## Solver Flow

1. `validate_merge_data()` checks schema, uniqueness, non-negative counts and
   weights, per-row grade totals, target consistency, and structural
   estimability.
2. `generate_candidate_clusters()` creates deterministic within-province
   candidate clusters. Positive-sample singletons are allowed; zero-sample
   singletons are forbidden.
3. `.build_milp()` constructs a set-partitioning mixed-integer linear program.
   Exact-cover constraints ensure every original cell is selected once.
4. `.feasibility_solve()` checks strict target feasibility.
5. `.find_min_delta()` searches the minimum uniform target relaxation when
   strict intervals are infeasible and `relax_targets = TRUE`.
6. `.lexicographic_solve()` optimizes the selected feasible model by
   lexicographic stages: moved sample size, demographic distance, outcome
   heterogeneity, weight distortion, and merge count.
7. `.build_fit_outputs()` creates final cells, original-to-final cell maps,
   merge steps, target results, province results, national fine-cell results,
   and audit tables.
8. `audit_merge_fit()` re-checks the final solution for positive final sample
   size, exact cover, and conservation.

## Source Map

```text
r-package/R/spec.R         schema and merge specification helpers
r-package/R/validate.R     input and target validation
r-package/R/candidates.R   deterministic candidate-cluster generation
r-package/R/model.R        MILP construction and HiGHS integration
r-package/R/fit.R          fit orchestration, relaxation, lexicographic solve
r-package/R/results.R      output tables, summaries, export, audit
r-package/R/print.R        print, summary, and plot methods
r-package/R/consent.R      disclaimer and session consent gate
r-package/R/example.R      example data and targets
r-package/R/utils.R        internal helpers
```

## Primary User Outputs

- `cell_map(fit)` maps original cells to final clusters.
- `merge_plan(fit)` lists ordered merge operations.
- `final_cells(fit)` returns one row per final merged cluster.
- `target_results(fit)` compares target intervals to initial and final
  weighted proportions.
- `province_results(fit)` summarizes provincial ABCD proportions.
- `national_cell_results(fit)` summarizes non-zero national fine cells.
- `calculate_results(fit, by = ...)` aggregates initial and final proportions
  over arbitrary dimensions.
- `audit_merge_fit(fit)` validates the fitted object.
- `export_merge_results(fit, path)` writes CSV outputs and the fit object.

## Current Status

Version `0.1.0` is an experimental package release candidate. The package has
tests, a vignette, GitHub Actions configuration, a pkgdown configuration, and
CRAN-oriented metadata, but CRAN submission should wait until `R CMD check
--as-cran` has been run locally and CI is green.
