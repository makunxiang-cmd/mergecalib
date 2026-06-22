# AGENTS.md — handoff guide for mergecalib

This file orients an AI agent or a new developer taking over `mergecalib`. Read
it before making changes. It is intentionally specific about the invariants this
package must preserve.

## 1. What the package does

`mergecalib` builds a deterministic, **within-province** plan that merges
demographic cells so that weighted outcome proportions (grades A/B/C/D) for
provincial and national populations fall inside user-supplied intervals. The
core is a set-partitioning mixed-integer linear program (MILP) solved with
HiGHS, followed by a lexicographic minimisation of secondary objectives.

The single most important domain rule: **every final merged cell must have a
strictly positive sample size**, and the package must never invent observations
or borrow sample across provinces by default.

## 2. Repository layout

```
DESCRIPTION, NAMESPACE        package metadata and exports (NAMESPACE is hand-maintained;
                              keep it in sync with roxygen if you run roxygen2)
R/                            source
  spec.R        merge_spec(), schema helpers, default_candidate_levels()
  validate.R    validate_merge_data() + .validate_targets()
  candidates.R  generate_candidate_clusters() and cluster metrics
  model.R       MILP construction (.build_milp) and HiGHS solve (.solve_highs)
  fit.R         fit_merge_calibration() orchestration, relaxation, lexicographic stages
  results.R     output tables, calculate_results(), audit_merge_fit(), export_merge_results()
  print.R       print/summary/plot S3 methods
  consent.R     disclaimer + session consent gate (mergecalib_disclaimer/agree)
  zzz.R         .onAttach startup banner
  utils.R       small internal helpers (.mc_stop, wildcards, ordering, etc.)
  example.R     example_merge_data(), example_merge_targets()
man/            hand-written .Rd files (NOT generated with the usual roxygen header)
tests/testthat/ unit tests (testthat edition 3)
vignettes/      mergecalib.Rmd (English)
inst/extdata/   example CSVs
inst/DISCLAIMER.md   canonical disclaimer text (read by consent.R)
.github/        CI (R-CMD-check, pkgdown), issue/PR templates
_pkgdown.yml    pkgdown site config
cran-comments.md submission notes
```

Note: the broader user folder also contains `Rscripts/`, `docs/`, and
`package/` (a built tarball) **outside** this package directory. The git
repository root is this package directory.

## 3. Hard invariants — do not break these

1. **Positive final sample size.** Zero-sample cells can never be standalone
   candidates; each must be absorbed into a same-province positive cell. The
   deterministic zero-absorption fallback in `candidates.R` guarantees a
   feasible partition exists. `audit_merge_fit()` re-checks `final_n > 0`.
2. **No fabricated sample / no default cross-province borrowing.** If a province
   is all-zero, or a target population has zero observed sample, the package
   errors out (see `validate.R`) instead of producing a result.
3. **Determinism.** Fixed lexicographic ordering, single-threaded HiGHS, fixed
   random seed, parallel off (see defaults in `.solve_highs` and `fit.R`).
   Identical inputs + same version => identical output. Do not introduce
   randomness into defaults.
4. **English + ASCII-only R source.** All user-facing messages are English. The
   only non-ASCII concept (the Chinese "national" wildcard) is encoded as a
   `\uXXXX` escape in `R/utils.R` (`.mc_wildcards`). Keep source ASCII so CRAN
   raises no non-ASCII NOTE.
5. **Conservation.** Sample size, total weight, and per-grade counts are
   conserved by merging; `audit_merge_fit()` enforces this.

## 4. The disclaimer / consent gate

`fit_merge_calibration()` calls `.mc_require_consent()` after checking that HiGHS
is installed. Behaviour:

- If `getOption("mergecalib.agreed")` is `TRUE`, proceed silently.
- If **non-interactive** (R CMD check, scripts, CI, vignettes): proceed, emitting
  a one-time `message()`. This must never block — CRAN checks depend on it.
- If **interactive** and not yet agreed: show the banner and `utils::menu()`;
  agreeing sets the session option, declining errors.

Never make this gate write to disk or block non-interactive runs. The canonical
text lives in `inst/DISCLAIMER.md`; `consent.R` has a built-in fallback copy —
keep them consistent if you edit the wording.

## 5. Build, document, test

R is required (not bundled in some sandboxes). Typical loop:

```r
devtools::load_all()
devtools::document()   # only if you change roxygen; then reconcile NAMESPACE
devtools::test()
devtools::check()
```

Release-grade:

```sh
R CMD build .
R CMD check --as-cran mergecalib_0.1.0.tar.gz
```

Tests assume HiGHS is available for the fit test (`skip_if_not_installed`).
Validation tests match **English** error substrings — if you reword an error,
update `tests/testthat/test-validation.R`.

## 6. Roadmap toward CRAN (priority order)

1. Run `R CMD check --as-cran` locally and on win-builder; drive to
   0/0/0 (a "New submission" NOTE is expected). Fill in `cran-comments.md`.
2. Confirm man pages match the code signatures (they are hand-written; if you
   adopt roxygen2 fully, regenerate and remove hand-written `.Rd`s).
3. Add an ORCID and a `Date` field to `DESCRIPTION` if desired; verify the
   maintainer email is reachable (CRAN emails it).
4. Consider adding `\value` and richer `@examples` (wrapped in
   `\dontrun{}` where they need the solver) to every exported function — CRAN
   requires `\value` on all exported functions.
5. Optionally add more tests (relaxation path, export round-trip,
   `calculate_results` by multiple dims) to raise coverage.
6. Tag `v0.1.0`, let CI go green, then submit via `devtools::release()`.

## 7. Common pitfalls

- Editing a message in `R/` but forgetting the matching test assertion.
- Reintroducing non-ASCII text (Chinese comments/strings) — keep it ASCII.
- Changing candidate-generation order or solver threads and breaking
  reproducibility.
- Forgetting that `man/*.Rd` are hand-maintained; a new exported function needs
  a new `.Rd` and a `NAMESPACE` export.
