# mergecalib Project

`mergecalib` is a structured R-package project for deterministic
within-province demographic cell merging and interval calibration.

## Repository Layout

```text
.
├── README.md
├── AGENTS.md
├── 项目说明与发展方向_中文.md
├── r-package/          # R package source
├── docs/               # project documentation and user manuals
├── examples/           # runnable example scripts
├── dist/               # local build artifacts, not versioned by default
├── tools/              # local utility scripts
└── .github/            # GitHub Actions and community templates
```

## Start Here

- R package source: [`r-package/`](r-package/)
- Package README: [`r-package/README.md`](r-package/README.md)
- Maintainer docs: [`docs/maintainer/README.md`](docs/maintainer/README.md)
- Agent handoff: [`AGENTS.md`](AGENTS.md)
- Chinese project note: [`项目说明与发展方向_中文.md`](项目说明与发展方向_中文.md)

## Quick Test

From the repository root:

```sh
cd r-package
Rscript -e 'devtools::test()'
```

Release-grade checks:

```sh
cd r-package
R CMD build .
R CMD check --as-cran mergecalib_0.1.0.tar.gz
```

The package requires the HiGHS R interface for solver-backed tests and examples:

```r
install.packages("highs")
```

