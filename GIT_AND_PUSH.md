# Git and GitHub push instructions

The repository is already initialised in this directory (the package root), the
default branch is `main`, an initial commit exists, and the remote `origin`
points to:

    https://github.com/makunxiang-cmd/mergecalib.git

I cannot authenticate to GitHub from here, so the final push is one step you run
locally.

## 1. Create the GitHub repo (if it does not exist yet)

Create an **empty** repository named `mergecalib` under your account
`makunxiang-cmd` (no README/license/.gitignore — this repo already has them).

## 2. Push

From the package directory (`.../mergecalib/mergecalib_sourcecode`):

```sh
git push -u origin main
```

You will be prompted to authenticate. Two common options:

- **HTTPS + Personal Access Token (PAT):** when asked for a password, paste a
  GitHub PAT (Settings -> Developer settings -> Personal access tokens) with
  `repo` scope.
- **GitHub CLI:** `gh auth login`, then the push above just works.

Or run the helper:

```sh
sh push_to_github.sh
```

## 3. Optional: switch the remote to SSH

```sh
git remote set-url origin git@github.com:makunxiang-cmd/mergecalib.git
git push -u origin main
```

## 4. After the first push

- GitHub Actions (`R-CMD-check`) runs automatically on push/PR.
- To publish the pkgdown site, enable GitHub Pages for the `gh-pages` branch
  after the `pkgdown` workflow runs once.
- Tag the release when checks are green: `git tag v0.1.0 && git push --tags`.
