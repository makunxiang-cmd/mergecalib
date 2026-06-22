## Submission summary

This is the first CRAN submission of mergecalib (version 0.1.0).

mergecalib builds deterministic within-province cell-merging plans for
demographic cell data using a set-partitioning mixed-integer linear program
solved with the HiGHS solver (via the 'highs' package), followed by a
lexicographic minimisation of secondary objectives.

## Test environments

- local: <fill in your OS> R <fill in version>
- GitHub Actions (via .github/workflows/R-CMD-check.yaml):
  - macOS-latest (release)
  - windows-latest (release)
  - ubuntu-latest (devel, release, oldrel-1)
- win-builder: devel and release  <run before submitting>

## R CMD check results

0 errors | 0 warnings | <n> notes  <fill in after running R CMD check --as-cran>

Expected possible NOTE on first submission:
* "New submission" — this is the initial release.

## Reverse dependencies

None (new package).

## Additional notes

- The package interacts with the user once per interactive session to confirm a
  short usage disclaimer. This prompt is fully skipped in non-interactive use
  (R CMD check, scripts, CI, vignettes) and never writes to the user's
  filespace; session consent is stored only in `options()`.
- Examples and the vignette do not call the solver during checks
  (`eval = FALSE` / `skip_if_not_installed("highs")`), keeping check time low.
