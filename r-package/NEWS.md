# mergecalib 0.2.0.9000

- Added classed mergecalib error and warning conditions for v0.2.0 development.
- Reworked candidate generation to compute demographic distances by province
  block instead of allocating a full-dataset distance matrix.
- Added conservative post-fit warnings for large relaxation, high weight
  distortion, high heterogeneity, and near-binding targets.
- Expanded tests around condition classes, candidate invariants, and warning
  controls.

# mergecalib 0.1.0

- First installable source release.
- Implements within-province candidate-cluster generation and a
  set-partitioning MILP.
- Makes "every final cluster must have a positive sample size" a hard
  constraint.
- Automatically constructs a zero-sample absorption partition for each province.
- Supports provincial, national-marginal, and cross-classified ABCD target
  intervals.
- Supports lexicographic objective optimisation and a minimum uniform target
  relaxation.
- Provides the cell mapping, merge steps, proportion results, and a full audit.
- Adds a CRAN-safe user disclaimer with `mergecalib_disclaimer()` and
  `mergecalib_agree()`, surfaced on attach and before the first interactive fit.
- All user-facing messages and documentation are in English.
