# rawvignette

<!-- badges: start -->
<!-- badges: end -->

Streamlined workflow for pre-compiled R package vignettes, for package
authors whose vignettes need to do intensive computational work.

## The problem

R package vignettes sometimes need to contain computationally intensive
code &mdash; long run times, API calls, large datasets. But this often leads to
issues when your package is built remotely by CRAN, GitHub Actions, or pkgdown, 
or to extremely slow local R CMD checks. The common workarounds (`eval = FALSE` 
chunks, manually cached `.rds` files, hidden precompute chunks) all have drawbacks.

Pre-computing your vignette locally is often a great solution. But common
approaches for pre-computed vignettes have some friction points, like setup
and configuration complexities, incompatibility with certain CI environments,
or file formats that don't play nicely with IDEs like RStudio.

## The solution

`rawvignette` tries to make the pre-compiled vignette workflow as streamlined
as possible, including setup and iteration, in the same way that 
`usethis::use_vignette()` does for standard vignettes.

Rather than running your vignette code at package-build time, the workflow
splits rendering into two stages: a *source* stage with live, executable code
(kept in `vignettes-raw/`) that you run locally when you want to, and a
*staged* `.Rmd` in `vignettes/` whose code has already been executed and whose
outputs have been inlined. Downstream tools &mdash; `R CMD check`, CRAN, pkgdown 
&mdash; only ever see the staged form, so they never re-execute your intensive code.

## Installation

```r
remotes::install_github("matthewkling/rawvignette")
# or
pak::pak("matthewkling/rawvignette")
```

## File layout

```
your-package/
├── vignettes/
│   ├── myvignette.Rmd          # knitted; committed; shipped
│   └── figures/                # generated figures; committed; shipped
├── vignettes-raw/
│   └── myvignette.Rmd          # real source; committed; NOT shipped
└── .Rbuildignore               # includes ^vignettes-raw$
```

## Functions

- `use_raw_vignette()` &ndash; scaffold a new precompiled vignette or migrate an existing one
- `precompile_raw_vignettes()` &ndash; knit `vignettes-raw/` sources to `vignettes/` outputs
- `check_raw_vignettes()` &ndash; flag precompiled vignettes whose source mtime is newer than their output

## Workflow

1. Call `use_raw_vignette()` to set up the scaffolding for a new vignette,
   or to migrate an existing vignette to the pre-compiled workflow.
2. Edit `vignettes-raw/<name>.Rmd`. This is the real source code for your
   vignette; use your IDE, run chunks interactively, iterate freely.
3. Run `precompile_raw_vignettes()` to (re)generate the shipped
   `vignettes/<name>.Rmd` and any figures.
4. Commit changes to both files and any figure PNGs.
5. Before a release, use `check_raw_vignettes()` to sanity-check freshness.

## Comparison to other pre-compilation approaches

- **The `.Rmd.orig` convention**: widely used [rOpenSci recommendation][1], 
and the closest relative to `rawvignette` &mdash; same two-stage rendering idea,
just with the source renamed `.Rmd.orig` rather than placed in a sibling
directory. The rename strips IDE recognition (in RStudio you lose syntax
highlighting, chunk controls, and the Knit button). `rawvignette` keeps the
source as `.Rmd` in `vignettes-raw/` so tools treat it normally, and
streamlines setup and compilation via helper functions.
- **`knitr` chunk caching (`cache = TRUE`)**: caches chunk results in a
sibling `_cache/` directory and skips re-execution on subsequent knits.
Useful for fast local iteration, but the cache directory isn't shipped
with the package, so CRAN, GitHub Actions, and pkgdown all re-execute
from scratch. `rawvignette` solves that problem at the cost of an
explicit precompile step.
- **`xfun::cache_rds()`**: a more flexible alternative to chunk-level
caching, with finer control over what's cached and when. Same fundamental
limitation: caches are designed for local iteration, not for bundling
into the shipped package. CRAN still re-executes unless you configure
that explicitly.
- **`R.rsp` pre-built vignettes**: ships pre-rendered HTML as the vignette.
Works, but pkgdown can't re-style the vignette to match your site theme
since it's already baked. `rawvignette`'s output is still an `.Rmd`, which
pkgdown can render with the rest of the site.
- **Articles (`usethis::use_article()`)**: the pkgdown-only alternative.
Good for ancillary content that doesn't need to ship with the package.
Not good for core tutorials: articles aren't installed locally, don't
appear on CRAN, and aren't discoverable via `vignette()`. Use
`rawvignette` when the content deserves first-class status.

[1]: https://ropensci.org/blog/2019/12/08/precompute-vignettes/
