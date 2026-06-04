# Check whether raw vignettes/articles are in sync with their outputs

Compares modification times of each `vignettes-raw/<path>.Rmd`
(recursively, so articles under `articles/` are included) against its
corresponding `vignettes/<path>.Rmd`. A source newer than its output
means the output is stale and should be regenerated with
[`precompile_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/precompile_raw_vignettes.md).

## Usage

``` r
check_raw_vignettes()
```

## Value

A data frame with columns `name`, `source`, `output`, `source_mtime`,
`output_mtime`, and `status` (one of `"fresh"`, `"stale"`, or
`"missing_output"`). Returned invisibly. Also emits a message
summarizing any stale items.

## What this catches

The common case: you edited the raw source and forgot to precompile
before committing or releasing. mtime comparison reliably catches this.

## What this does not catch

This check uses file modification times as a heuristic and will miss
several categories of true staleness. Treat its "fresh" verdict as a
weak guarantee, not a strong one. Specifically, it cannot detect:

- **Changes to package source code.** If you edit `R/foo.R` so that
  `foo()` now returns different output, the captured output is logically
  stale even though the source `.Rmd` is unchanged.

- **Changes to data files.** Updates to `inst/extdata/`, `data/`, or any
  external file the source reads from will not be detected.

- **Changes to dependency package versions.** If a dependency changes
  behavior between rebuilds, the captured output may no longer reflect
  what the code now produces.

- **Touched-but-unchanged sources.** Opening and re-saving the source
  without editing it updates its mtime and falsely reports staleness.

- **Branch switches.** `git checkout` updates file mtimes, which can
  make everything look stale immediately after switching branches.

For a robust freshness guarantee, the only reliable approach is to run
[`precompile_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/precompile_raw_vignettes.md)
whenever any plausibly-relevant input has changed.
