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

## Session log and working files

Work sessions often break off, so keep a record that survives them:

- After every prompt, write the user's prompt and your final result text
  to `.claude/last-session.md` (overwrite it each time). Before starting new
  work, read it if the user asks to continue where the last session stopped.
- Put all temporary files, screenshots and videos under `.claude/tmp/`
  (e.g. `.claude/tmp/screenshots/`), not in the system temp directory or the
  scratchpad, so they can be opened from the workspace file tree.
- These files are local only; `.claude/last-session.md` and `.claude/tmp/`
  are git-ignored.
