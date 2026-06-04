# Install a pre-commit hook that checks precompiled-vignette freshness

Writes a git `pre-commit` hook that runs
[`check_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/check_raw_vignettes.md)
and aborts the commit if any precompiled vignette or article is stale
(its `vignettes-raw/` source is newer than its `vignettes/` output).
This catches the common slip of editing a raw source and forgetting to
run
[`precompile_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/precompile_raw_vignettes.md)
before committing.

## Usage

``` r
use_raw_vignette_hook(
  on_collision = c("error", "append", "overwrite"),
  remove = FALSE
)
```

## Arguments

- on_collision:

  One of `"error"`, `"append"`, `"overwrite"`. See Collision handling.

- remove:

  If `TRUE`, remove the `rawvignette` hook instead of installing it. If
  the hook was appended (sentinel markers present), only the marked
  block is stripped, leaving the rest intact; if that leaves an empty
  hook, the file is deleted. If the whole file is a rawvignette-only
  hook, it is deleted. Other files are left untouched.

## Value

Invisibly, the path to the hook file (or `NULL` if nothing was
written/removed).

## Details

The hook is a plain shell script written to `.git/hooks/pre-commit`, in
the same spirit as the README hook installed by
`usethis::use_readme_rmd()`. It does **not** depend on the `precommit`
framework (no Python).

## Scope and limitations

This is a *local* convenience, not a guarantee:

- It lives in `.git/hooks/`, which is not version-controlled, so it does
  not propagate to collaborators or survive a fresh clone. Each clone
  must run this again.

- Like
  [`check_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/check_raw_vignettes.md),
  it compares modification times and so only catches
  *source-edited-but-not-reknitted*. It cannot detect staleness caused
  by changes to package code, data, or dependencies, and may
  false-positive right after a `git checkout` (which rewrites mtimes).
  Use `git commit --no-verify` to bypass in that case.

- The only robust freshness guarantee is to re-run
  [`precompile_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/precompile_raw_vignettes.md)
  before a release.

## Collision handling

Git supports a single `pre-commit` hook file, which may already be in
use (e.g. the README hook from `usethis::use_readme_rmd()`). The
`on_collision` argument controls what happens when
`.git/hooks/pre-commit` already exists:

- `"error"` (default): do nothing and stop, with a message explaining
  the `"append"` and `"overwrite"` alternatives.

- `"append"`: add this check to the existing hook, wrapped in
  `rawvignette` sentinel markers so it can be updated or removed later
  without disturbing the rest of the file. Re-running replaces the
  marked block rather than duplicating it.

- `"overwrite"`: replace the entire hook file with a fresh one
  containing only this check. Destroys any existing hook content.

If no hook exists yet, a new one is written regardless of
`on_collision`.
