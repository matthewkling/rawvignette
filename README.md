# rawvignette

<!-- badges: start -->
[![R-CMD-check](https://github.com/matthewkling/rawvignette/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/matthewkling/rawvignette/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Streamlined workflow for pre-compiled R package vignettes and pkgdown
articles, for package authors whose documentation needs to do intensive
computational work.

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

## A solution

`rawvignette` tries to make the pre-compiled vignette workflow as streamlined
as possible, including setup and iteration, in the same way that 
`usethis::use_vignette()` and `usethis::use_article()` does for standard 
vignettes and articles.

Rather than running your vignette code at package-build time, the workflow
splits rendering into two stages: a *source* stage with live, executable code
(kept in `vignettes-raw/`) that you run locally when you want to, and a
*staged* `.Rmd` in `vignettes/` whose code has already been executed and whose
outputs have been inlined. Downstream tools &mdash; `R CMD check`, CRAN, pkgdown 
&mdash; only ever see the staged form, so they never re-execute your intensive code.

The same workflow covers both **package vignettes** (shipped with the package,
discoverable via `vignette()`, visible on CRAN) and **pkgdown articles**
(web-only, excluded from the package tarball). Which one you get is determined
by whether the source lives in an `articles/` subdirectory.


## Installation

```r
pak::pak("matthewkling/rawvignette")
```


## File layout

```
your-package/
├── vignettes/
│   ├── myvignette.Rmd          # knitted; committed; shipped
│   ├── figures/                # vignette figures; committed; shipped
│   └── articles/               # web-only; .Rbuildignored (NOT shipped)
│       ├── myarticle.Rmd        #   knitted; committed; web-only
│       └── myarticle_files/     #   article figures; web-only
├── vignettes-raw/
│   ├── myvignette.Rmd          # real vignette source; committed; NOT shipped
│   └── articles/
│       └── myarticle.Rmd        # real article source; committed; NOT shipped
└── .Rbuildignore               # includes ^vignettes-raw$ and ^vignettes/articles$
```

Plots produced by code chunks are handled automatically (generated as figures
during precompilation). Vignette figures sit in the shipped `vignettes/figures/`.
Article figures live inside the build-ignored `vignettes/articles/` subtree, so 
a single `^vignettes/articles$` entry keeps both the rendered article and its 
figures out of the package tarball. 

### Files your vignette depends on
 
Two kinds of dependency are worth noting, because the source now lives 
in `vignettes-raw/` while the shipped output lives in `vignettes/`:
 
- **Files read at knit time** (e.g. `read.csv("data.csv")` in a chunk). These
  are needed only while precompiling, which knits from `vignettes-raw/`, so
  place them beside the source there. They won't ship &mdash; which is correct,
  since their result is already baked into the output &mdash; or you can address
  package data path-independently with `system.file()`.
- **Files the rendered page links to** (e.g. a hand-made `![](diagram.png)`).
  pkgdown copies these from beside the *output*, so they must live under
  `vignettes/` (for articles, under `vignettes/articles/`). `precompile_raw_vignettes()`
  warns if the rendered document links to such a file that isn't present beside
  the output.


## Functions

- `use_raw_vignette()` &ndash; scaffold a new precompiled vignette or article, or migrate an existing one. Pass an `articles/` prefix (e.g. `use_raw_vignette("articles/benchmark")`) to scaffold an article.
- `precompile_raw_vignettes()` &ndash; knit `vignettes-raw/` sources (recursively, including `articles/`) to their `vignettes/` outputs
- `check_raw_vignettes()` &ndash; flag precompiled vignettes and articles whose source mtime is newer than their output
- `use_raw_vignette_hook()` &ndash; (optional) install a git pre-commit hook that runs `check_raw_vignettes()` and blocks a commit if any output is stale


## Workflow

1. Call `use_raw_vignette()` to set up the scaffolding for a new vignette or
   article, or to migrate an existing one to the pre-compiled workflow.
2. Edit `vignettes-raw/<name>.Rmd`. This is the real source code; use your
   IDE, run chunks interactively, iterate freely.
3. Run `precompile_raw_vignettes()` to (re)generate the shipped output(s)
   and any figures.
4. Commit changes to both files and any figure files.
5. Before a release, use `check_raw_vignettes()` to sanity-check freshness.

To catch the most common slip &mdash; editing a `vignettes-raw/` source and
forgetting to precompile before committing &mdash; you can optionally install a
git pre-commit hook with `rawvignette::use_raw_vignette_hook()`. This runs 
`check_raw_vignettes()` on every commit and blocks the commit if any
output is stale. The hook is a convenience, not a guarantee: it compares file
modification times, so it catches an un-precompiled edit but not staleness from
changed package code, data, or dependencies &mdash; and because it lives in
`.git/hooks/` it isn't version-controlled and must be re-installed per clone.
For a robust guarantee, re-run `precompile_raw_vignettes()` before a release.


## Comparison to other pre-compilation approaches

- **The `.Rmd.orig` convention**: widely used [rOpenSci recommendation][1], 
and the closest relative to `rawvignette` &mdash; same two-stage rendering idea,
just with the source renamed `.Rmd.orig` rather than placed in a sibling
directory. The rename strips IDE recognition (in RStudio you lose syntax
highlighting, chunk controls, and the Knit button). `rawvignette` keeps the
source as `.Rmd` in `vignettes-raw/` so tools treat it normally, and
streamlines setup and compilation via helper functions. It also handles
figure routing, orphan cleanup, `.Rbuildignore` management, and a freshness
check &mdash; the parts the convention leaves you to script per-package.
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
- **`R.rsp` static vignettes**: ships a pre-rendered PDF or self-contained
HTML file as the vignette (via the `R.rsp::asis` engine). Works well for
content built outside the R Markdown pipeline, but the baked artifact isn't
something pkgdown can re-render into your site theme. `rawvignette`'s output
is still an `.Rmd`, which pkgdown renders with the rest of the site.
- **Articles (`usethis::use_article()`)**: creates a plain (non-precompiled)
pkgdown article &mdash; web-only, `.Rbuildignore`d, not installed locally or on
CRAN. This circumvents issues with CRAN, but some articles are still too
compute-intensive to get rebuilt by pkgdown every time you push to GitHub.
Pre-compiled `rawvignette` articles solve this.

[1]: https://ropensci.org/blog/2019/12/08/precompute-vignettes/
[2]: https://r-pkgs.org/vignettes.html
