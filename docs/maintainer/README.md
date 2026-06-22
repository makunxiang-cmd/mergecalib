# Project Documentation

This directory holds maintainer-facing documentation for `mergecalib`.

## Start Here

- [Project overview](PROJECT_OVERVIEW.md) explains the package purpose,
  architecture, solver flow, outputs, and hard invariants.
- [Development guide](DEVELOPMENT.md) covers local setup, testing, manual
  documentation, release checks, and repository hygiene.
- [GitHub publishing](GITHUB_PUBLISHING.md) records the remote, branch, and push
  workflow.
- [v0.2.0 roadmap](ROADMAP_v0.2.0.md) is the staged technical roadmap after
  v0.1.0.
- [Root agent handoff](../AGENTS.md) is the canonical file for AI agents and new
  maintainers taking over the repository.

## Repository Boundary

The Git repository root is the project root:

```text
/Users/makunxiang/Documents/AI编程/R Pack/mergecalib
```

The R package source lives in `r-package/`. Root-level visible files are kept to
`README.md`, `AGENTS.md`, and the Chinese project note; other content is grouped
under purpose-specific directories.

The package's pkgdown workflow builds the public website into
`r-package/docs/` during CI. Maintainer-authored documentation belongs here in
`docs/maintainer/` so it does not collide with generated site output.
