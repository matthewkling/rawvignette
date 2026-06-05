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
article. There is deliberately no separate flag – the source location is
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

## Article figure rendering (matching pkgdown)

A native pkgdown article is knitted by pkgdown itself, which applies the
figure settings from its `figures:` field (defaults plus any
`_pkgdown.yml` overrides) – notably `fig.retina`, which gives pkgdown
figures their high-resolution rendering, and a device/dpi pairing. A
precompiled article is knitted here instead, so without intervention it
would use knitr's plain defaults and the baked figures would look
smaller and lower-resolution than a native article, and would carry
knitr's "plot of chunk" caption fallback.

To keep precompiled articles visually identical to native ones, the
article branch pulls pkgdown's current figure settings via
[`pkgdown::fig_settings()`](https://pkgdown.r-lib.org/reference/fig_settings.html)
and applies them as chunk-option defaults before knitting. Because these
are *defaults* set before the knit, any figure option the author sets in
their own setup chunk or per-chunk still wins. The figure device matches
pkgdown's
([`ragg::agg_png`](https://ragg.r-lib.org/reference/agg_png.html)) when
the ragg package is installed, and otherwise falls back to knitr's
default PNG device; resolution parity holds either way, since it is
driven by `dpi` and `fig.retina` rather than the device itself.

One pkgdown figure setting is deliberately *not* applied: `fig.asp`.
Unlike inert defaults such as `dpi` or `fig.retina`, a document-wide
`fig.asp` actively recomputes each chunk's `fig.height` as
`fig.width * fig.asp`, which would silently override any per-chunk
`fig.height` an author sets and force every figure to one aspect ratio.
Only an inert default `fig.width` is applied; figure heights are left to
per-chunk options and knitr's defaults, so per-chunk sizing works as
authored.

pkgdown is required to precompile an article (it is a pkgdown concept);
the call errors if pkgdown is not installed. Vignettes are unaffected –
they never enter this branch.

## Which version of the package is captured

Precompiling runs your source chunks in the current R session, so the
output captures whatever version of *your* package that session resolves
when the source calls
[`library(yourpkg)`](https://rdrr.io/r/base/library.html) (or
`yourpkg::fn()`). This is worth being deliberate about, because it
determines what users will see baked into the shipped document:

- From a plain R session, the **installed** version of your package is
  used – the one in your library, not necessarily your working tree.

- After `devtools::load_all()` (or while your package is otherwise
  loaded from source), that source version shadows the installed one and
  is used instead, following R's normal namespace resolution.

The practical implication: precompiling mid-development with
`load_all()` bakes in output from your uninstalled working tree, which
may not match what an installed user gets. That is often convenient
while iterating, but for the **final** precompile before a release,
install the package first (e.g. `devtools::install()`) and precompile
from a clean session, so the captured output reflects the version users
will actually run. This is also why
[`check_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/check_raw_vignettes.md)
can only offer a weak freshness guarantee – it cannot see that the
captured output came from a different package version than is currently
installed.

Run from the package root.
