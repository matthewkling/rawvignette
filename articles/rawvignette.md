# Precompiled vignettes and articles with rawvignette

``` r

library(rawvignette)
```

By default, R rebuilds your vignettes every time the package is built –
during `R CMD check`, on CRAN, on GitHub Actions, and when pkgdown
generates your site. Usually that is a good thing: it keeps the rendered
output honest.

## The problem

But when a vignette (or a pkgdown article) does heavy work – a long or
memory-intensive computation, a call to a rate-limited API, a large
dataset – rebuilding it everywhere, every time, can become annoying or
impossible.

Here is the kind of chunk that causes the trouble. Imagine the
[`Sys.sleep()`](https://rdrr.io/r/base/Sys.sleep.html) below is an
intensive simulation that depends on a large input dataset and takes two
hours to run:

``` r

expensive_result <- {
  Sys.sleep(2)  # stand-in for genuinely slow work
  summary(1:1000)
}
expensive_result
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>     1.0   250.8   500.5   500.5   750.2  1000.0
```

If that chunk lives in an ordinary vignette, every build server needs
access to the input data and has to run a two-hour job each time the
vignette is built.

## The idea

The goal of `rawvignette` is to build the vignette once, on your
machine, and ship the already-computed result.

The workflow splits a vignette into two stages:

- A **source** in `vignettes-raw/`, with live, executable code. You edit
  and run this locally, whenever you choose.
- A **staged** `.Rmd` in `vignettes/`, produced by knitting the source.
  Its code has already been executed and its output inlined, so there is
  nothing expensive left to run.

Downstream tools only ever see the staged form. `R CMD check`, CRAN, and
pkgdown re-knit it, but since its chunks are already evaluated, that
re-knit is instant.

This is the well-established “precompiled vignette” idea (see the
[rOpenSci tech
note](https://ropensci.org/blog/2019/12/08/precompute-vignettes/));
`rawvignette` just adds tooling around it – scaffolding, figure
handling, `.Rbuildignore` management, and a freshness check – so you do
not have to script those by hand.

## Walking through the workflow

The functions expect to run from a package root. To keep this vignette
self-contained and runnable, the examples below operate in a disposable
throwaway package created in a temporary directory (set up invisibly
when this vignette starts). In your own work you would skip that step
and simply run the workflow from your package’s top level.

### 1. Scaffold a source

[`use_raw_vignette()`](https://matthewkling.github.io/rawvignette/reference/use_raw_vignette.md)
sets up a skeleton for a new pre-compiled vignette or article. You can
also use it to migrate an existing standard vignette or article to the
`rawvignette` workflow. The function wires up the supporting
infrastructure (the `vignettes-raw/` directory, a `.Rbuildignore` entry,
and a `vignettes/figures/` directory for vignettes), and either creates
a new vignette/article `.Rmd` file for you to edit, or moves your
existing `.Rmd` into the new directory.

``` r

use_raw_vignette("intro", title = "Introduction")
#> Created vignettes-raw/intro.Rmd
#> Added `^vignettes-raw$` to .Rbuildignore
#> 
#> Next steps:
#>   1. Edit vignettes-raw/intro.Rmd
#>   2. Run: `rawvignette::precompile_raw_vignettes()`
#>   3. Commit vignettes-raw/intro.Rmd, vignettes/intro.Rmd, and any new figures.  4. [OPTIONAL] Run `rawvignette::use_raw_vignette_hook()` to configure a
#>      pre-commit check for stale vignettes, so you don't forget to precompile.
```

That leaves you with a skeleton source to edit:

``` r

list.files("vignettes-raw")
#> [1] "intro.Rmd"
```

In real use you would now open `vignettes-raw/intro.Rmd` and write your
vignette there, iterating and running code the same way you would for a
normal vignette. For the demo, let’s drop in a chunk that does some
(pretend-expensive) work:

``` r

writeLines(c(
  "---",
  'title: "Introduction"',
  "output: rmarkdown::html_vignette",
  "vignette: >",
  "  %\\VignetteIndexEntry{Introduction}",
  "  %\\VignetteEngine{knitr::rmarkdown}",
  "  %\\VignetteEncoding{UTF-8}",
  "---",
  "",
  "```{r}",
  "# Pretend this is slow:",
  "nrow(mtcars)",
  "```"
), "vignettes-raw/intro.Rmd")
```

### 2. Precompile

[`precompile_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/precompile_raw_vignettes.md)
knits every source under `vignettes-raw/` to its counterpart in
`vignettes/`, running the code once and inlining the results. It also
injects a “do not edit by hand” notice identifying the source.

``` r

precompile_raw_vignettes()
#> Knitting vignettes-raw/intro.Rmd -> vignettes/intro.Rmd
```

The shipped vignette now exists, with the computed output baked in:

``` r

list.files("vignettes")
#> [1] "figures"   "intro.Rmd"
out <- readLines("vignettes/intro.Rmd")
cat(head(out, 20), sep = "\n")
```

    #> ---
    #> title: "Introduction"
    #> output: rmarkdown::html_vignette
    #> vignette: >
    #>   %\VignetteIndexEntry{Introduction}
    #>   %\VignetteEngine{knitr::rmarkdown}
    #>   %\VignetteEncoding{UTF-8}
    #> ---
    #> 
    #> <!--
    #>   =====================================================================
    #>   WARNING: THIS FILE IS GENERATED by rawvignette. Do not edit by hand.
    #>   Source: vignettes-raw/intro.Rmd
    #>   Regenerate with: rawvignette::precompile_raw_vignettes()
    #>   =====================================================================
    #> -->
    #> 
    #> 
    #> ``` r
    #> # Pretend this is slow:

Notice the generated notice at the top: editing `vignettes/intro.Rmd`
directly would be a mistake, because the next precompile overwrites it.
The source of truth is `vignettes-raw/intro.Rmd`.

### 3. Check freshness

Because the two files can drift – you edit the source, then forget to
re-precompile – you can use
[`check_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/check_raw_vignettes.md)
to compares their file modification times and flags any stale output.

``` r

check_raw_vignettes()
#> All precompiled vignettes are fresh (by mtime; see ?check_raw_vignettes for caveats).
```

Right after precompiling, everything is fresh. If you now edit the
source without re-precompiling, the check notices:

``` r

# Simulate editing the source after the output was built.
Sys.setFileTime("vignettes-raw/intro.Rmd", Sys.time() + 5)
check_raw_vignettes()
#> Stale precompiled vignette:
#>   - intro
#> Run rawvignette::precompile_raw_vignettes() to regenerate.
```

This is a heuristic, not a guarantee. It catches the common slip – an
un-precompiled edit – but cannot detect staleness caused by changes to
your package code, data files, or dependency versions, since those do
not touch the source `.Rmd`. The only robust guarantee is to re-run
[`precompile_raw_vignettes()`](https://matthewkling.github.io/rawvignette/reference/precompile_raw_vignettes.md)
before a release.

To catch the forgot-to-precompile slip automatically, you can install a
git pre-commit hook that runs the freshness check and blocks a commit
when an output is stale, using
[`use_raw_vignette_hook()`](https://matthewkling.github.io/rawvignette/reference/use_raw_vignette_hook.md).
If you already have a pre-commit hook (for example, the one
`usethis::use_readme_rmd()` installs), pass `on_collision = "append"` to
add the check alongside it instead of replacing it. The hook is a local
convenience: it lives in `.git/hooks/`, so it is not version-controlled
and must be re-installed per clone, and like the freshness check it
compares modification times only. See
[`?use_raw_vignette_hook`](https://matthewkling.github.io/rawvignette/reference/use_raw_vignette_hook.md)
for details.

## Articles

pkgdown also displays **articles**: vignette-like documents that appear
on your website but do not ship with the package (handy for content that
is large, depends on unavailable resources, or simply does not belong on
CRAN). `rawvignette` precompiles articles the same way – the main
difference is where they live.

Pass an `articles/` prefix, and the source goes to
`vignettes-raw/articles/`, the output to `vignettes/articles/`, and an
extra `.Rbuildignore` entry keeps the whole `vignettes/articles/`
subtree (rendered article plus its figures) out of the package tarball:

``` r

use_raw_vignette("articles/benchmark", title = "Benchmark")
```

This creates an `Rmd.` with slightly different header parameters,
appropriate for a pkgdown article. Everything else – editing,
precompiling, the freshness check – works identically. There is no
separate flag to set; the `articles/` location is the single signal that
a document is an article rather than a vignette.

## When to use `rawvignette`

Precompilation has a real cost: your documentation no longer rebuilds
automatically when the package changes, so you take on the discipline of
re-precompiling when relevant inputs change. That trade is worth it for
genuinely expensive vignettes, and not worth it for cheap ones.
Precompile the documents that are slow, flaky, or resource-hungry; leave
the rest as ordinary vignettes.
