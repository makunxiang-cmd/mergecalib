# GitHub Publishing

The repository is initialized at the project root. The default branch is `main`
and `origin` points to:

```text
https://github.com/makunxiang-cmd/mergecalib.git
```

## Check The Remote

```sh
git remote -v
git status -sb
```

## First-Time Repository Setup

If the GitHub repository does not exist yet, create an empty repository named
`mergecalib` under `makunxiang-cmd`. Do not initialize it with a README,
license, or `.gitignore`; this repository already provides those files.

## Push

```sh
git push -u origin main
```

Authentication options:

- HTTPS with a GitHub personal access token that can write to the repository.
- GitHub CLI authentication with `gh auth login`.

The helper script remains available:

```sh
sh tools/push_to_github.sh
```

## Optional SSH Remote

```sh
git remote set-url origin git@github.com:makunxiang-cmd/mergecalib.git
git push -u origin main
```

## After Push

- GitHub Actions runs `R-CMD-check` automatically on push and pull requests.
- Enable GitHub Pages for the `gh-pages` branch after the pkgdown workflow runs
  once.
- Tag a release only after checks are green:

```sh
git tag v0.1.0
git push --tags
```
