# Contributing to mergecalib

Thanks for your interest in improving `mergecalib`. This document explains how to
set up the package for development and the conventions the project follows.

## Development setup

```r
# from the package root
install.packages(c("devtools", "roxygen2", "testthat", "highs"))
devtools::load_all()
```

The mandatory runtime dependency is the HiGHS solver interface
(`install.packages("highs")`).

## Workflow

1. Create a feature branch from `main`.
2. Make your change, including tests under `tests/testthat/`.
3. Regenerate documentation if you changed roxygen comments:
   `devtools::document()`.
4. Run the checks below and make sure they are clean.
5. Open a pull request describing the change and linking any related issue.

## Required checks before a PR

```r
devtools::document()
devtools::test()
devtools::check()           # aim for 0 errors / 0 warnings / 0 notes
```

For a release-grade check:

```r
R CMD build .
R CMD check --as-cran mergecalib_*.tar.gz
```

## Coding conventions

- **English and ASCII only** in R source. User-facing messages must be English;
  if a non-ASCII literal is unavoidable, use a `\uXXXX` escape (see
  `R/utils.R`).
- Keep the package **deterministic**: fixed ordering, single-threaded solving,
  fixed random seed. Do not introduce randomness into default behaviour.
- Preserve the hard guarantees: every final cluster must have a positive sample
  size, and the package must never fabricate sample for zero-observation
  populations or borrow across provinces by default.
- Add or update tests for any behavioural change. New error paths should have a
  test that matches the (English) message.
- Follow the existing two-space indentation and snake_case naming.

## Reporting issues

Please use the issue templates and include a minimal reproducible example.
