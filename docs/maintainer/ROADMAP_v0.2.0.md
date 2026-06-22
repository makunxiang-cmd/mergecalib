# mergecalib — v0.2.0 development roadmap

**Status:** v0.2.0 is an *intermediate development release*, not a CRAN
submission. It exists to land the algorithmic, statistical, and engineering
enhancements agreed with the maintainer. CRAN submission happens only after a
later hardening pass (testing, feature selection, performance tuning); see
[Road to CRAN](#9-road-to-cran-post-020).

This roadmap was produced from a four-lens review (mathematics / optimization,
statistics, systems engineering, software engineering) of the v0.1.0 source.

---

## 1. Guiding principles (must not regress)

Every change below must preserve the v0.1.0 invariants:

1. **Positive final sample size** — no zero-sample final cluster; zero-sample
   cells are always absorbed.
2. **No fabricated sample; no default cross-province borrowing.**
3. **Determinism** — identical inputs + version => identical output. Any
   parallelism must be order-deterministic.
4. **Conservation** — sample size, total weight, per-grade counts conserved.
5. **English + ASCII-only R source** (non-ASCII only via `\uXXXX`).

A change that improves performance or ergonomics but weakens any invariant is
rejected.

---

## 2. Workstream A — Optimization / solver core

### A1. Elastic relaxation diagnostics (replaces single uniform `delta`) — **priority 1**

**Problem.** `.find_min_delta()` binary-searches one uniform relaxation applied
to every target. It answers "how much slack overall" but not "which targets are
binding and by how much."

**Plan.** Add an elastic / goal-programming formulation: introduce per-target,
per-side slack variables `s_lower[t], s_upper[t] >= 0`, relax each constraint by
its own slack, and minimise an aggregate of slacks. Offer two objectives:

- `relaxation = "minimax"` — minimise the maximum slack (generalises the current
  uniform `delta`; backward-compatible default).
- `relaxation = "l1"` — minimise the sum of slacks (sparser, identifies the few
  binding targets).

**API.** `fit_merge_calibration(..., relaxation = c("uniform","minimax","l1"))`;
keep `relax_targets`/`max_delta` working. New `target_results()` columns:
`slack_lower`, `slack_upper`, `binding` (logical).

**Acceptance.** On an infeasible example, the report lists exactly which targets
carry positive slack; `minimax` reproduces the v0.1.0 `delta` within tolerance.

### A2. Province decomposition + optional deterministic parallelism — **priority 1**

**Insight.** The MILP couples provinces **only** through national / cross-province
targets. With province-level targets only, the problem is fully separable.

**Plan.**
- Detect whether any target spans more than one province (membership crosses
  provinces). If none, solve each province as an independent subproblem.
- Provide `parallel = FALSE` (default) and an opt-in deterministic parallel
  backend over provinces (e.g. `future.apply`/`parallel` in Suggests); results
  are merged in a fixed province order so output stays reproducible.
- When national targets exist, keep the coupled MILP but still build the model
  province-block-aware (see A3).

**Acceptance.** Province-only problems produce identical results to v0.1.0 but
measurably faster; parallel and serial runs are bit-identical.

### A3. Block-diagonal distance matrix — **priority 1**

**Problem.** `.distance_matrix()` builds a dense `N x N` matrix over the **whole**
dataset, then indexes per province — `O(N^2)` memory for national-scale data.

**Plan.** Compute and store distances per province block only (the cross-province
entries are never used). Keep the public behaviour of
`generate_candidate_clusters()` unchanged.

**Acceptance.** Peak memory for candidate generation scales with the largest
province, not total `N`; candidate output is byte-identical.

### A4. Normalised, configurable distance metric — **priority 2**

**Problem.** Ordinal dimensions contribute up to `(#levels - 1)` while nominal
dimensions contribute `0/1 * weight`; the scales are not comparable.

**Plan.** Normalise ordinal gaps to `[0, 1]` (Gower-style) before weighting;
expose a `distance` hook so users can supply a custom metric (see C3).

**Acceptance.** Default behaviour documented; a regression test pins the new
default distances; custom metric path covered by a test.

### A5. Column generation for large provinces — **stretch / likely 0.3.0**

**Problem.** The candidate pool is a heuristic subset, so the "optimum" is only
optimal within that pool.

**Plan (experimental, behind a flag).** Prototype a column-generation loop:
solve the LP relaxation, price new candidate clusters from reduced costs, add
the best, repeat. Ship as `experimental_column_generation = FALSE` and document
it as not affecting default results.

**Acceptance.** On a crafted instance, column generation finds a strictly better
objective than the staged heuristic, with determinism preserved.

### A6. Lexicographic tolerance hardening — **priority 3**

Document the `value + tol` cut drift; add a test asserting higher-priority
objectives are not degraded beyond `lex_tolerance_*` across stages.

---

## 3. Workstream B — Statistical diagnostics

### B1. Weight-distortion diagnostics: CV / design effect / ESS — **priority 1**

**Plan.** Add `weight_diagnostics(fit)` returning, overall and per province:
before/after **weight CV**, Kish **design effect** `deff = 1 + CV^2`, and
**effective sample size** `ESS = n / deff`. Surface a compact summary in
`print()`/`summary()`.

**Acceptance.** Numbers match hand computation on the example; documented
formulas in the vignette.

### B2. Calibration diagnostic report — **priority 1**

**Plan.** Add `calibration_report(fit)`: per target the initial vs final
proportion, distance to interval **centre**, `binding` flag (from A1), and
detection of mutually conflicting targets (e.g. overlapping populations whose
intervals cannot jointly hold). Add a `plot(fit, type = "binding")`.

**Acceptance.** Conflicting-target fixture is flagged; report aligns with
`target_results()`.

### B3. Proportion standard errors / confidence intervals — **priority 2**

**Plan.** Provide uncertainty for final weighted proportions via linearisation
(Taylor) as the default and an optional bootstrap (resampling cells within
province). Expose through `target_results(..., se = TRUE)` /
`calculate_results(..., se = TRUE)`.

**Caveat to document.** These SEs treat the merge plan as fixed; they do **not**
capture model-selection uncertainty from choosing the plan.

**Acceptance.** Linearised SE matches a survey-package cross-check on the example
within tolerance; bootstrap is reproducible under the fixed seed.

---

## 4. Workstream C — Adaptability / architecture

### C1. Condition classes for all failure modes — **priority 1**

**Plan.** Replace generic `stop()` with classed conditions (e.g.
`mergecalib_error_structural`, `_not_estimable`, `_solver`, `_weight_bounds`,
`_infeasible`). Provide a small constructor in `utils.R`. Keep messages English.

**Acceptance.** Each error path is `tryCatch`-able by class; validation tests
assert on class, not just message substrings.

### C2. Warning layer for "valid but risky" situations — **priority 1**

**Plan.** Emit `warning()` (classed) when: a large `delta`/slack was needed; a
final cluster's weight distortion or `max_weight_ratio` exceeds a threshold; a
cluster is highly heterogeneous; a target is near-binding. Add
`options(mergecalib.warn = TRUE/FALSE)` and thresholds.

**Acceptance.** Each warning has a fixture and is suppressible.

### C3. Pluggable solver and metric backends — **priority 2**

**Plan.** Define a thin solver interface (`solve_milp(model, control)`) with
HiGHS as the default implementation; allow registering alternatives
(`Rglpk`, `gurobi`) via Suggests. Allow a user-supplied `distance` function and
custom objective columns/order (extend the existing `objective_order`).

**Acceptance.** HiGHS path unchanged; a mock backend solves the example through
the interface in a test.

### C4. Internationalised (zh/en) messages — **priority 2**

**Plan.** Route user-facing strings through `gettextf()`; add a `po/` directory
with a Chinese translation so messages localise by `LC_MESSAGES`. Keep source
ASCII; translations live in `.po` files.

**Acceptance.** With a Chinese locale, errors/warnings appear in Chinese; English
is the fallback; `R CMD check` reports no non-ASCII in R sources.

### C5. Input inclusivity — **priority 2**

**Plan.** Accept `tibble`/`data.table` (coerce safely, preserve column order);
explicitly support an arbitrary number of grades (already supported in code —
document and test with 2 and 6 grades); accept weights given either as a cell
total or as a unit weight via `merge_spec(weight_type = c("total","unit"))`.

**Acceptance.** Tests cover tibble/data.table input, 2/4/6 grades, and both
weight conventions.

---

## 5. Workstream D — Text feedback / observability

- **D1.** Optional progress/verbose mode (`verbose = TRUE`) reporting candidate
  counts per level, feasibility per stage, and delta/slack search steps;
  optionally via the `cli` package (Suggests).
- **D2.** Toggle to surface the HiGHS solver log (`solver_control$log = TRUE`).
- **D3.** Richer `print()`/`summary()`: include ESS/deff (B1) and the binding
  target count (A1/B2).

**Acceptance.** Verbose output is off by default and does not change results.

---

## 6. Workstream E — Testing & quality (pervasive)

Expand `tests/testthat/` to cover, at minimum:

- relaxation paths: `relax_targets = FALSE`, `max_delta` cap, `minimax` vs `l1`;
- every error path by **condition class** (A-C);
- `export_merge_results()` round-trip (write then read CSV/RDS);
- `calculate_results()` over single and multiple dimensions;
- S3 methods `print`/`summary`/`plot`;
- custom `merge_spec()` column mapping and wildcard matching (incl. the
  `全国` national wildcard);
- 2-grade and 6-grade specifications;
- province decomposition equivalence (A2) and parallel/serial bit-identity;
- diagnostics (B1-B3) against hand-computed values.

Target: meaningful coverage on every exported function; CI matrix already in
`.github/workflows/R-CMD-check.yaml`.

---

## 7. Documentation deliverables for 0.2.0

- New vignette sections: elastic relaxation, weight diagnostics, calibration
  report, decomposition/performance notes.
- Runnable examples on every exported function (wrap solver calls in
  `\donttest{}`); decide roxygen-vs-handwritten `.Rd` (recommend migrating to
  roxygen2 and regenerating).
- Update `NEWS.md`; update `AGENTS.md` for new internals (solver interface,
  condition classes, decomposition).

---

## 8. Suggested sequencing (milestones)

1. **0.2.0-alpha (foundations):** A3 (distance blocking), C1 (condition
   classes), C2 (warnings), E (test scaffold). Low-risk, unlocks the rest.
2. **0.2.0-beta (algorithms):** A1 (elastic), A2 (decomposition/parallel),
   B1/B2 (diagnostics), D (feedback).
3. **0.2.0 (polish):** A4 (metric), B3 (SE/CI), C3/C4/C5 (pluggable/i18n/inputs),
   docs, full test pass.
4. **Deferred to 0.3.0:** A5 (column generation, experimental).

---

## 9. Road to CRAN (post-0.2.0)

After 0.2.0 stabilises:

1. Feature-freeze; run `R CMD check --as-cran` and win-builder to 0/0/0
   (a "New submission" NOTE is expected). Fill in `cran-comments.md`.
2. Ensure every exported function has `\value` and a runnable example.
3. Confirm the interactive consent gate never blocks checks and writes nothing
   to disk (already designed this way — keep a regression test).
4. Decide the final public API surface (hide experimental flags such as column
   generation behind clearly documented switches).
5. Tag, let CI go green, then submit via `devtools::release()`.

---

## 10. Definition of done for 0.2.0

- All workstream A1-A4, B1-B3, C1-C5, D1-D3 items implemented or explicitly
  deferred with a tracked issue.
- All v0.1.0 invariants verified by tests.
- `devtools::check()` clean except known pre-CRAN gaps tracked for the CRAN pass.
- Determinism re-verified (serial vs parallel bit-identity).
- `NEWS.md`, vignette, and `AGENTS.md` updated.
