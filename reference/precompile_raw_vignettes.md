# Precompile raw vignettes and articles

Knits each `vignettes-raw/<path>.Rmd` to `vignettes/<path>.Rmd` and
injects a "do not edit" notice at the top of the output identifying the
source and how to regenerate.

## Usage

``` r
precompile_raw_vignettes(names = NULL, quiet = TRUE)
```

## Arguments

- names:

  Character vector of source paths relative to `vignettes-raw/`, without
  extension (e.g. `"intro"` or `"articles/benchmark"`). If `NULL` (the
  default), all `.Rmd` files anywhere under `vignettes-raw/` are
  rebuilt.

- quiet:

  Passed to [`knitr::knit()`](https://rdrr.io/pkg/knitr/man/knit.html).
  Suppresses the chunk-by-chunk progress messages.

## Value

Invisibly, the paths of the rebuilt output files.

## Details

Sources may live in subdirectories of `vignettes-raw/`. The subdirectory
structure is mirrored into `vignettes/`. In particular, sources under
`vignettes-raw/articles/` become pkgdown *articles* at
`vignettes/articles/` (web-only documentation excluded from the package
tarball via `.Rbuildignore`), while sources at the top level become
package vignettes.

Figures are routed per source:

- Vignette figures go to `vignettes/figures/`, prefixed by the vignette
  name, and ship with the package.

- Article figures go to rmarkdown's default location beneath
  `vignettes/articles/`, so they sit inside the build-ignored article
  subtree and are *not* shipped to CRAN. (pkgdown ignores a custom
  `fig.path`, so articles must use the default; see Details.)

After a successful knit, vignette figures matching the vignette's prefix
that weren't touched by the current run are treated as orphans and
deleted. Article figure directories are pruned wholesale before each
knit instead (see Details).

## Articles vs vignettes

Whether a source is treated as an article is auto-detected from its
path: anything under `articles/` (relative to `vignettes-raw/`) is an
article. There is deliberately no separate flag — the source location is
the single source of truth, so a no-argument call does the right thing
across a mixed tree.

## Article figure handling

pkgdown re-knits articles when building the site and, per its docs,
ignores any custom `fig.path` because the default is "a strong
assumption of rmarkdown". We therefore let article figures land in the
rmarkdown default location (`<name>_files/`) beside the output. Because
that directory is recreated on every knit, we cannot use the mtime
orphan heuristic reliably across renamed chunks; instead the whole
`<name>_files/` directory is removed before knitting so each run starts
clean.

Run from the package root.
