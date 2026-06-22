# Development Guide

## Prerequisites

Install R 4.1 or newer and the package dependencies:

```r
install.packages(c("Matrix", "graphics", "stats", "utils", "highs"))
install.packages(c("devtools", "testthat", "knitr", "rmarkdown", "roxygen2"))
```

`highs` is required for solver-backed examples and tests.

## Local Workflow

Run these from the R package directory:

```r
setwd("r-package")
devtools::load_all()
devtools::test()
devtools::check()
```

Release-grade checks:

```sh
cd r-package
R CMD build .
R CMD check --as-cran mergecalib_0.1.0.tar.gz
```

## Documentation

The `man/*.Rd` files are currently hand-maintained. If a function signature,
argument, return value, or export changes, update the matching `.Rd` file and
`NAMESPACE` entry in the same change.

If the project later migrates fully to roxygen2, regenerate documentation with:

```r
devtools::document()
```

Then inspect the generated `man/` and `NAMESPACE` diffs before committing.

## Testing Notes

- `tests/testthat/test-fit.R` skips solver checks if `highs` is unavailable.
- Validation tests assert on English error substrings. Update the tests when
  changing user-facing messages.
- The consent gate must never block non-interactive runs, including tests,
  examples, vignettes, and CI.
- Keep deterministic defaults: single-threaded HiGHS, fixed random seed,
  parallel branching off, fixed ordering, and lexicographic objectives.

## CRAN Readiness Checklist

- `R CMD check --as-cran` reports 0 errors and 0 warnings.
- Any notes are understood and documented in `cran-comments.md`.
- Every exported function has complete help, including value documentation.
- Examples are runnable or wrapped appropriately for solver-dependent paths.
- Maintainer email in `DESCRIPTION` can receive CRAN confirmation email.
- The package tarball does not include repository-only files such as `.github/`,
  root `docs/`, examples, local handoff files, or local built artifacts.

## Repository Hygiene

- Keep user-facing package documentation in English.
- Keep R source ASCII-only. The Chinese national wildcard is represented by
  escaped Unicode in `R/utils.R`.
- Do not commit local built tarballs, rendered PDFs, `.Rproj.user/`, or
  `.DS_Store`.
- Repository-level documents, examples, tools, and built artifacts stay outside
  `r-package/` unless they are meant to ship with the R package.
