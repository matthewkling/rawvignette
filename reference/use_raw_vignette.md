# Scaffold a raw (precompiled) vignette or article

Creates the infrastructure for a precompiled vignette or pkgdown
article. Whether you get a vignette or an article is determined by
`name`: a name under `articles/` (e.g. `"articles/benchmark"`) scaffolds
a web-only pkgdown article; any other name scaffolds a package vignette.

## Usage

``` r
use_raw_vignette(name, title = NULL)
```

## Arguments

- name:

  Vignette or article name, without extension. Use an `articles/` prefix
  (e.g. `"articles/benchmark"`) to scaffold an article.

- title:

  Title. Defaults to the basename of `name`. Ignored if migrating an
  existing file (the existing title is preserved).

## Value

Invisibly, the path to the raw source file.

## Details

For a **vignette** (`name = "intro"`):

- `vignettes-raw/intro.Rmd` (the editable source)

- `^vignettes-raw$` in `.Rbuildignore`

- `vignettes/figures/` (where generated figures land; ships with pkg)

For an **article** (`name = "articles/benchmark"`):

- `vignettes-raw/articles/benchmark.Rmd` (the editable source)

- `^vignettes-raw$` and `^vignettes/articles$` in `.Rbuildignore` (the
  latter keeps the rendered article and its figures out of the package
  tarball, so compute-heavy articles never burden CRAN)

- The skeleton omits the `vignette:` YAML block, so R does not treat it
  as a package vignette.

If `vignettes/<name>.Rmd` already exists, it is migrated to
`vignettes-raw/<name>.Rmd` rather than overwritten.

After running this, edit the skeleton, then call
[`precompile_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/precompile_raw_vignettes.md)
to generate the shipped output.

## Migrating files that read or link to other files

Migration moves only the `.Rmd`; any sidecar files (a data CSV, an
`.rds`, a linked image) are left in place, and `use_raw_vignette()`
emits a note listing them. Where such a file should live depends on how
it is used:

- A file read **at knit time** (e.g. `read.csv("data.csv")` in a chunk)
  should sit beside the source, since precompiling knits from
  `vignettes-raw/`. Co-locating it there is fine and it won't ship (the
  directory is build-ignored). Alternatively, address package data
  path-independently, e.g. via
  [`system.file()`](https://rdrr.io/r/base/system.file.html).

- A file the **rendered output** links to (e.g. an image pkgdown must
  copy when building the site) should remain under `vignettes/`, where
  pkgdown looks for it.

A file used both ways may need to exist in both places. Because the
source now lives in a different directory than the shipped output, paths
that were relative to the old `vignettes/` location are no longer
automatically valid for both stages.
