# AGENTS.md - handoff guide for mergecalib

This is the canonical handoff file for AI agents and new maintainers taking
over `mergecalib`. Read it before making changes.

## 1. Repository Boundary

The GitHub repository root is the project root:

```text
/Users/makunxiang/Documents/AI编程/R Pack/mergecalib
```

The R package itself lives in `r-package/`. Keep the repository root clean:
visible root files should be limited to `README.md`, `AGENTS.md`, and
`项目说明与发展方向_中文.md`; other project content belongs in folders.

## 2. What The Package Does

`mergecalib` builds deterministic within-province cell-merging plans for
demographic cell data. It calibrates weighted outcome proportions for provincial
and national target populations against user-supplied intervals.

The computational core is:

1. deterministic candidate-cluster generation;
2. set-partitioning mixed-integer linear programming with HiGHS;
3. optional minimum uniform target relaxation;
4. lexicographic minimization of secondary objectives;
5. final audit of exact cover, conservation, and positive final sample size.

The single most important domain rule is that every final merged cell must have
strictly positive sample size. The package must never invent observations or
borrow sample across provinces by default.

## 3. Documentation Map

- `README.md` - root project map and quick commands.
- `r-package/README.md` - package-facing installation, example, input format,
  outputs, and scope.
- `docs/maintainer/README.md` - maintainer documentation index.
- `docs/maintainer/PROJECT_OVERVIEW.md` - architecture, solver flow, outputs,
  and source map.
- `docs/maintainer/DEVELOPMENT.md` - setup, test, documentation, release, and
  CRAN notes.
- `docs/maintainer/ROADMAP_v0.2.0.md` - staged technical roadmap.
- `docs/maintainer/GITHUB_PUBLISHING.md` - remote and push workflow.
- `docs/user-manual/` - rendered user manuals and PDFs.
- `examples/` - runnable scripts outside the R package source.
- `r-package/vignettes/mergecalib.Rmd` - package vignette.
- `r-package/cran-comments.md` - CRAN submission notes.

## 4. Source Map

```text
r-package/DESCRIPTION, NAMESPACE        package metadata and exports
r-package/R/spec.R                      merge_spec(), schema helpers
r-package/R/validate.R                  data and target validation
r-package/R/candidates.R                candidate clusters and metrics
r-package/R/model.R                     MILP construction and HiGHS solve
r-package/R/fit.R                       orchestration and lexicographic solve
r-package/R/results.R                   outputs, summaries, audit, export
r-package/R/print.R                     print, summary, and plot methods
r-package/R/consent.R                   disclaimer and consent gate
r-package/R/zzz.R                       .onAttach startup banner
r-package/R/utils.R                     internal helpers and wildcard matching
r-package/R/example.R                   example data and targets
r-package/tests/testthat/               unit tests
r-package/man/                          hand-written Rd files
r-package/inst/DISCLAIMER.md            canonical disclaimer text
.github/                                CI and GitHub templates
docs/maintainer/                        maintainer-facing documentation
```

## 5. Hard Invariants

Do not break these:

1. Positive final sample size. Zero-sample cells cannot stand alone; they must
   be absorbed into same-province positive-sample clusters.
2. No fabricated sample and no default cross-province borrowing. All-zero
   provinces and unestimable target populations must error rather than produce
   pseudo-results.
3. Determinism. Keep fixed ordering, single-threaded HiGHS, fixed random seed,
   parallel off by default, and lexicographic objectives.
4. Conservation. Merging must preserve sample size, total weight, and per-grade
   counts. `audit_merge_fit()` is the final guard.
5. English user-facing package messages and ASCII-only R source. The Chinese
   national wildcard is encoded as escaped Unicode in `R/utils.R`.

## 6. Consent Gate

`fit_merge_calibration()` calls `.mc_require_consent()` before solving.

- `getOption("mergecalib.agreed") == TRUE` proceeds silently.
- Non-interactive sessions proceed with a one-time message and must never block.
- Interactive sessions show the disclaimer and ask for session consent.

Never make this gate write to disk. Keep `R/consent.R` and
`inst/DISCLAIMER.md` consistent if the wording changes.

## 7. Build, Test, Check

Typical local loop:

```r
setwd("r-package")
devtools::load_all()
devtools::test()
devtools::check()
```

Release-grade loop:

```sh
cd r-package
R CMD build .
R CMD check --as-cran mergecalib_0.1.0.tar.gz
```

If `highs` is not installed, solver-backed tests are skipped. Validation tests
match English error substrings, so rewording errors can require test updates.

## 8. Manual Documentation

`man/*.Rd` files are hand-maintained. If you add or change an exported function,
update all of these together:

1. the R function;
2. `NAMESPACE`;
3. the matching `man/*.Rd`;
4. examples, README, vignette, and tests when behavior changes.

Do not run roxygen2 casually unless you intend to inspect and reconcile the
generated `man/` and `NAMESPACE` changes.

## 9. CodeGraph

The local MCP environment may expose CodeGraph tools. Prefer CodeGraph for
structural questions when an index exists. In this checkout, CodeGraph was not
initialized when this handoff was written; if the tool reports that
`.codegraph/` is missing, ask before running `codegraph init -i`.

## 10. Common Pitfalls

- Reintroducing non-ASCII strings into R source.
- Changing candidate ordering, solver thread defaults, or random seeds and
  breaking reproducibility.
- Editing error text without updating validation tests.
- Adding exported functions without synchronized `.Rd` and `NAMESPACE` updates.
- Treating files outside this Git repository as automatically part of the
  package source.
