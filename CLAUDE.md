# Everbond

## Git workflow

- `main` is the release branch; `dev` is the integration branch.
- Do every change on its own branch cut from `dev`, named by type:
  `feat/...` (features), `fix/...` (bug fixes), `docs/...`, `refactor/...`.
  Don't commit directly on `dev` or `main`.
- Merge the branch into `dev` with `git merge --no-ff` so the merge commit
  is kept in history. Merges into `main` also use `--no-ff`.
- Only commit, push, or merge when asked. Pushing a branch and pushing
  `dev`/`main` are separate steps: push `dev`/`main` only on an explicit request.
