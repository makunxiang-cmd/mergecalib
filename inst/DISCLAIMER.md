# mergecalib DISCLAIMER

_Last updated: 2026-06-22 - applies to mergecalib and all versions unless superseded._

By installing, loading, or using the `mergecalib` package you acknowledge and
agree to the terms below. In an interactive R session you will be asked to
confirm this disclaimer before the first model is fitted; you may also
acknowledge it in advance with `mergecalib_agree(TRUE)`.

## 1. Nature of the software

`mergecalib` is a statistical computation and optimisation tool. It builds
deterministic, within-province cell-merging plans by solving a set-partitioning
mixed-integer linear program (MILP) and then lexicographically minimising a
sequence of secondary objectives. It does **not** make survey-design,
weighting, or scientific decisions on your behalf.

## 2. User responsibilities

You are solely responsible for confirming that:

- the target intervals, demographic variable definitions, weight semantics, and
  merging rules match the statistical design, business rules, and legal or
  regulatory requirements of your own project;
- the input data are correct, complete, and appropriate for the analysis;
- the merge scope, resulting outcome heterogeneity, and final weight changes are
  reviewed and signed off by a qualified statistician before any result is used.

## 3. What the software will and will not do

- It does **not** create observations for populations that have no observed
  sample. If a target population has zero observed sample, the problem is
  reported as not estimable rather than filled with fabricated values.
- Under its default rules it does **not** borrow sample across provinces.
- If a province contains only zero-sample cells, the problem is reported as
  structurally infeasible and no pseudo-result is produced.

## 4. No guarantee of validity

Target feasibility does **not** imply unbiased or valid estimation. A plan that
places weighted proportions inside the requested intervals may still be
statistically inappropriate for your purpose. The numerical results depend on
the solver (HiGHS) and on the options you supply.

## 5. No warranty

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. See
the package `LICENSE` (MIT) for the full licence terms.

## 6. Not professional advice

The package and its documentation do not constitute statistical, legal,
financial, or other professional advice.
