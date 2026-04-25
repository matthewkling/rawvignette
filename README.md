# rawvignette

<!-- badges: start -->
<!-- badges: end -->

Streamlined workflow for precomputed R package vignettes.

## The problem

R package vignettes sometimes need to contain computationally intensive
code---long run times, API calls, large datasets. But this often leads to 
issues when your package built is remotely by CRAN, GitHub actions, or
pkgdown site constructors. The common workarounds (`eval = FALSE` chunks, 
manually cached `.rds` files, hidden precompute chunks) all have drawbacks.

Pre-computing your vignette locally is often a great solution. But common 
approaches for pre-computed vignettes have some friction points, like setup
and configuration complexities, incompatibility with certain CI environments, 
or file formats that don't place nicely with IDEs like RStudio.

## The solution

`rawvignette` tires to make the pre-compiled vignette workflow as streamlined
as possible, in the same way that `usethis::use_vignette()` does for
standard vignettes. Raw vignettes live in a sister directory to the main
vignette folder 

- Call `use_raw_vignette()` to set up the scaffolding for a new pre-compiled 
vignette, or migrate an existing vignette to the workflow.
- Run `precompile_raw_vignette()` to 
- Use `


Raw vignettes 

It provides functions to set up, compile, and check your
vignettes. 

Pre-compute the vignette locally, and commit the rendered output. CRAN, CI, 
and pkgdown consume the committed output directly---no expensive code runs 
in those contexts. Pre-computed vignettes are widely used for this, but have
some friction

This is the [pattern recommended by rOpenSci
in 2019][ropensci-post], with one tweak: the vignette source lives in
`vignettes-raw/` with it native `.Rmd` extension, rather than being renamed 
to `.Rmd.orig`, so it keeps full IDE support for R Markdown files (syntax 
highlighting, chunk controls, Knit button).

[ropensci-post]: https://ropensci.org/blog/2019/12/08/precompute-vignettes/

## Layout

```
your-package/
├── vignettes/
│   ├── myvignette.Rmd          # knitted; committed; shipped
│   └── figures/                # generated figures; committed; shipped
├── vignettes-raw/
│   ├── myvignette.Rmd          # real source; committed; NOT shipped
│   └── precompile.R            # rebuild script
└── .Rbuildignore               # includes ^vignettes-raw$
```

## Install

```r
remotes::install_github("YOURHANDLE/rawvignette")
# or
pak::pak("YOURHANDLE/rawvignette")
```

## Usage

From your package root:

```r
# Scaffold a new precompiled vignette, or migrate an existing one
rawvignette::use_raw_vignette("myvignette", title = "How to use myvignette")

# Edit vignettes-raw/myvignette.Rmd, then:
rawvignette::precompile_raw_vignettes()

# Before a release, sanity-check freshness:
rawvignette::check_raw_vignettes()
```

## Workflow

1. Edit `vignettes-raw/<name>.Rmd`. This is the real source — use your
   IDE, run chunks interactively, iterate freely.
2. Run `rawvignette::precompile_raw_vignettes()` to regenerate the shipped
   `vignettes/<name>.Rmd` and any figures.
3. Commit changes to both files and any new figure PNGs.

CRAN, `R CMD check`, and pkgdown all process the knitted `vignettes/<name>.Rmd`,
which contains no executable code — just fenced code blocks and
pre-rendered outputs. No expensive computation ever runs in CI.

## How it works

`knitr::knit()` executes the source document and *weaves* the results in:
the output `.Rmd` contains the original code as fenced code blocks,
followed by captured text output as `#>` comments and figures as file
references. When knitr later processes this "fake" `.Rmd` (during
`R CMD build`, pkgdown rendering, etc.), there are no executable knitr
chunks to run — just markdown to format.

A notice is injected at the top of the knitted `.Rmd` identifying it as
generated and pointing to the source.

## Why not ...

**`xfun::cache_rds()`** — caches expression results to `.rds` files.
Excellent for local iteration, but the cache directory isn't set up to
ship with the package by default, so CRAN still re-executes the expensive
code unless you configure things carefully. `rawvignette` takes the
opposite approach: skip the re-execution entirely.

**`R.rsp` pre-built vignettes** — ships pre-rendered HTML as the vignette.
Works, but pkgdown can't re-style the vignette to match your site theme
since it's already baked. `rawvignette`'s output is still an `.Rmd`,
which pkgdown can render with the rest of the site.

**The `.Rmd.orig` convention** — the original rOpenSci recommendation.
Identical in spirit, but renaming the source to `.orig` loses IDE
recognition. `rawvignette` keeps the source as `.Rmd` in a sibling
directory, so tools treat it normally.

**Articles (`usethis::use_article()`)** — the pkgdown-only alternative.
Good for ancillary content that doesn't need to ship with the package.
Not good for core tutorials: articles aren't installed locally, don't
appear on CRAN, and aren't discoverable via `vignette()`. Use
`rawvignette` when the content deserves first-class status.

## License

MIT

