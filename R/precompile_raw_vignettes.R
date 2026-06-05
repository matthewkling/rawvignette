#' Precompile raw vignettes and articles
#'
#' Knits each `vignettes-raw/<path>.Rmd` to `vignettes/<path>.Rmd` and
#' injects a "do not edit" notice at the top of the output identifying
#' the source and how to regenerate.
#'
#' Sources may live in subdirectories of `vignettes-raw/`. The
#' subdirectory structure is mirrored into `vignettes/`. In particular,
#' sources under `vignettes-raw/articles/` become pkgdown *articles* at
#' `vignettes/articles/` (web-only documentation excluded from the
#' package tarball via `.Rbuildignore`), while sources at the top level
#' become package vignettes.
#'
#' Figures are routed per source:
#' - Vignette figures go to `vignettes/figures/`, prefixed by the
#'   vignette name, and ship with the package.
#' - Article figures go to rmarkdown's default location beneath
#'   `vignettes/articles/`, so they sit inside the build-ignored article
#'   subtree and are *not* shipped to CRAN. (pkgdown ignores a custom
#'   `fig.path`, so articles must use the default; see Details.)
#'
#' After a successful knit, vignette figures matching the vignette's
#' prefix that weren't touched by the current run are treated as orphans
#' and deleted. Article figure directories are pruned wholesale before
#' each knit instead (see Details).
#'
#' @section Articles vs vignettes:
#' Whether a source is treated as an article is auto-detected from its
#' path: anything under `articles/` (relative to `vignettes-raw/`) is an
#' article. There is deliberately no separate flag -- the source location
#' is the single source of truth, so a no-argument call does the right
#' thing across a mixed tree.
#'
#' @section Article figure handling:
#' pkgdown re-knits articles when building the site and, per its docs,
#' ignores any custom `fig.path` because the default is "a strong
#' assumption of rmarkdown". We therefore let article figures land in the
#' rmarkdown default location (`<name>_files/`) beside the output. Because
#' that directory is recreated on every knit, we cannot use the mtime
#' orphan heuristic reliably across renamed chunks; instead the whole
#' `<name>_files/` directory is removed before knitting so each run starts
#' clean.
#'
#' @section Article figure rendering (matching pkgdown):
#' A native pkgdown article is knitted by pkgdown itself, which applies the
#' figure settings from its `figures:` field (defaults plus any
#' `_pkgdown.yml` overrides) -- notably `fig.retina`, which gives pkgdown
#' figures their high-resolution rendering, and a device/dpi pairing. A
#' precompiled article is knitted here instead, so without intervention it
#' would use knitr's plain defaults and the baked figures would look
#' smaller and lower-resolution than a native article, and would carry
#' knitr's "plot of chunk" caption fallback.
#'
#' To keep precompiled articles visually identical to native ones, the
#' article branch pulls pkgdown's current figure settings via
#' [pkgdown::fig_settings()] and applies them as chunk-option defaults
#' before knitting. Because these are *defaults* set before the knit, any
#' figure option the author sets in their own setup chunk or per-chunk
#' still wins. The figure device matches pkgdown's (`ragg::agg_png`) when
#' the ragg package is installed, and otherwise falls back to knitr's
#' default PNG device; resolution parity holds either way, since it is
#' driven by `dpi` and `fig.retina` rather than the device itself.
#'
#' One pkgdown figure setting is deliberately *not* applied: `fig.asp`.
#' Unlike inert defaults such as `dpi` or `fig.retina`, a document-wide
#' `fig.asp` actively recomputes each chunk's `fig.height` as
#' `fig.width * fig.asp`, which would silently override any per-chunk
#' `fig.height` an author sets and force every figure to one aspect ratio.
#' Only an inert default `fig.width` is applied; figure heights are left
#' to per-chunk options and knitr's defaults, so per-chunk sizing works as
#' authored.
#'
#' pkgdown is required to precompile an article (it is a pkgdown concept);
#' the call errors if pkgdown is not installed. Vignettes are unaffected --
#' they never enter this branch.
#'
#' @section Which version of the package is captured:
#' Precompiling runs your source chunks in the current R session, so the
#' output captures whatever version of *your* package that session
#' resolves when the source calls `library(yourpkg)` (or `yourpkg::fn()`).
#' This is worth being deliberate about, because it determines what users
#' will see baked into the shipped document:
#'
#' - From a plain R session, the **installed** version of your package is
#'   used -- the one in your library, not necessarily your working tree.
#' - After [devtools::load_all()] (or while your package is otherwise
#'   loaded from source), that source version shadows the installed one
#'   and is used instead, following R's normal namespace resolution.
#'
#' The practical implication: precompiling mid-development with
#' `load_all()` bakes in output from your uninstalled working tree, which
#' may not match what an installed user gets. That is often convenient
#' while iterating, but for the **final** precompile before a release,
#' install the package first (e.g. `devtools::install()`) and precompile
#' from a clean session, so the captured output reflects the version users
#' will actually run. This is also why [check_raw_vignettes()] can only
#' offer a weak freshness guarantee -- it cannot see that the captured
#' output came from a different package version than is currently
#' installed.
#'
#' Run from the package root.
#'
#' @param names Character vector of source paths relative to
#'   `vignettes-raw/`, without extension (e.g. `"intro"` or
#'   `"articles/benchmark"`). If `NULL` (the default), all `.Rmd` files
#'   anywhere under `vignettes-raw/` are rebuilt.
#' @param quiet Passed to [knitr::knit()]. Suppresses the chunk-by-chunk
#'   progress messages.
#' @return Invisibly, the paths of the rebuilt output files.
#' @export
precompile_raw_vignettes <- function(names = NULL, quiet = TRUE) {
      if (!file.exists("DESCRIPTION")) {
            stop("Run this from the package root (no DESCRIPTION found here).",
                 call. = FALSE)
      }

      raw_dir <- "vignettes-raw"
      if (!dir.exists(raw_dir)) {
            stop("No `vignettes-raw/` directory found. See use_raw_vignette().",
                 call. = FALSE)
      }

      if (is.null(names)) {
            src_files <- list.files(
                  raw_dir,
                  pattern    = "\\.Rmd$",
                  full.names = FALSE,
                  recursive  = TRUE
            )
            names <- tools::file_path_sans_ext(src_files)
      }

      if (length(names) == 0L) {
            message("No vignettes to precompile.")
            return(invisible(character()))
      }

      # Each iteration sets base.dir and fig.path explicitly (vignettes ->
      # vignettes/ with a flat figures/ dir; articles -> the article's own
      # output dir with rmarkdown's default _files location). We capture and
      # restore the originals here so the loop leaves global knitr opts as it
      # found them.
      old_base_dir <- knitr::opts_knit$get("base.dir")
      on.exit(knitr::opts_knit$set(base.dir = old_base_dir), add = TRUE)

      # Remember original fig.path so we can restore it after the loop
      old_fig_path <- knitr::opts_chunk$get("fig.path")
      on.exit(knitr::opts_chunk$set(fig.path = old_fig_path), add = TRUE)

      # The article branch sets several figure chunk options (dev, dpi,
      # fig.retina, ...) from pkgdown. Those are global knitr state, so we must
      # (a) restore them when we exit, and (b) reset them at the top of every
      # iteration -- otherwise an article's settings would leak out of the
      # function, and would bleed into a *vignette* built later in the same
      # call, silently changing the vignette's figures. We snapshot the keys
      # the article branch may touch and restore/reset exactly those.
      fig_opt_keys <- c("dev", "dpi", "fig.retina", "fig.width", "fig.cap")
      old_fig_opts <- knitr::opts_chunk$get(fig_opt_keys)
      reset_fig_opts <- function() {
            for (k in fig_opt_keys) {
                  knitr::opts_chunk$set(
                        stats::setNames(list(old_fig_opts[[k]]), k))
            }
      }
      on.exit(reset_fig_opts(), add = TRUE)

      vig_fig_dir <- file.path("vignettes", "figures")

      outputs <- character(length(names))
      for (i in seq_along(names)) {
            nm  <- names[i]
            src <- file.path(raw_dir, paste0(nm, ".Rmd"))
            out <- file.path("vignettes", paste0(nm, ".Rmd"))

            if (!file.exists(src)) {
                  warning("Source not found, skipping: ", src, call. = FALSE)
                  next
            }

            # Start each iteration from the captured figure-option baseline so
            # settings from a previous (article) iteration never carry over.
            reset_fig_opts()

            is_article <- is_article_path(nm)

            # Ensure the (possibly nested) output directory exists.
            dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)

            if (is_article) {
                  # Articles: use rmarkdown's default figure location beneath
                  # the article, since pkgdown ignores a custom fig.path.
                  #
                  # The figure files must land inside the build-ignored
                  # articles/ subtree (so they never reach CRAN) AND at the
                  # location the output's own relative image links point to.
                  # Both are satisfied by pointing base.dir at the output's
                  # OWN directory and using an unprefixed fig.path: the figure
                  # is written beside the output, and the relative link knitr
                  # emits resolves from the co-located output document. (Setting
                  # base.dir to vignettes/ and prefixing fig.path instead would
                  # make the written path and the emitted link disagree.)
                  base_name <- basename(nm)
                  art_base_dir <- normalizePath(dirname(out), mustWork = TRUE)
                  knitr::opts_knit$set(base.dir = art_base_dir)

                  # Apply pkgdown's figure settings as chunk-option DEFAULTS so
                  # the baked figures match a native pkgdown article (device,
                  # dpi, fig.retina) and don't get knitr's "plot of chunk"
                  # caption fallback. Errors if pkgdown is absent. Set these
                  # BEFORE fig.path: fig.path is ours to control (we are the
                  # knitter, not pkgdown), so it must be set last and not be
                  # overridden by the pkgdown options.
                  do.call(knitr::opts_chunk$set, pkgdown_fig_opts())
                  knitr::opts_chunk$set(
                        fig.path = paste0(base_name, "_files/figure-html/"))

                  fig_dir <- file.path(dirname(out), paste0(base_name, "_files"))
                  if (dir.exists(fig_dir)) {
                        unlink(fig_dir, recursive = TRUE)
                  }
            } else {
                  # Vignettes: shared base.dir (vignettes/) with a flat
                  # figures/ dir and a per-vignette prefix. Slashes in nm
                  # (shouldn't occur for top-level vignettes) are sanitized.
                  knitr::opts_knit$set(
                        base.dir = normalizePath("vignettes", mustWork = TRUE))
                  prefix <- gsub("/", "-", nm, fixed = TRUE)
                  knitr::opts_chunk$set(fig.path = paste0("figures/", prefix, "-"))
            }

            # Capture knit start time before knit runs so we can identify
            # vignette figure files not touched by this run (orphans).
            # Subtract a small margin for coarse-mtime filesystems.
            knit_start <- Sys.time() - 1

            message("Knitting ", src, " -> ", out,
                    if (is_article) " (article)" else "")
            knitr::knit(
                  input  = src,
                  output = out,
                  quiet  = quiet,
                  envir  = new.env(parent = globalenv())
            )
            inject_generated_notice(path = out, source_path = src)

            # Orphan cleanup applies only to the shared vignette figures dir.
            # Article figures were wiped pre-knit, so nothing to prune here.
            if (!is_article && dir.exists(vig_fig_dir)) {
                  prefix <- gsub("/", "-", nm, fixed = TRUE)
                  this_figs <- list.files(
                        vig_fig_dir,
                        pattern    = paste0("^", prefix, "-"),
                        full.names = TRUE
                  )
                  if (length(this_figs) > 0L) {
                        orphans <- this_figs[file.mtime(this_figs) < knit_start]
                        if (length(orphans) > 0L) {
                              message("Removing ", length(orphans),
                                      " orphaned figure(s): ",
                                      paste(basename(orphans), collapse = ", "))
                              file.remove(orphans)
                        }
                  }
            }

            # Warn about statically-linked resources the rendered doc needs
            # but that aren't present beside the output (so pkgdown can't
            # copy them). Best-effort; never fails the precompile.
            warn_missing_output_resources(src = src, out = out)

            outputs[i] <- out
      }

      invisible(outputs[nzchar(outputs)])
}

#' Is a source path (relative to vignettes-raw/, no extension) an article?
#' @noRd
is_article_path <- function(nm) {
      parts <- strsplit(nm, "/", fixed = TRUE)[[1]]
      length(parts) >= 2L && parts[1] == "articles"
}

#' Resolve the figure chunk options pkgdown would use for an article
#'
#' Returns a named list of knitr chunk options that mirror how pkgdown
#' renders article figures, so a precompiled article's baked figures match
#' a native one. Built from [pkgdown::fig_settings()], which merges the
#' `figures:` field of `_pkgdown.yml` over pkgdown's own defaults -- so we
#' track pkgdown's defaults without hard-coding them and pick up a user's
#' customizations automatically.
#'
#' The small translation applied here mirrors pkgdown's internal
#' `fig_opts_chunk()`: strip the namespace from the device name so knitr
#' accepts it, resolve the `fig.asp`-beats-`fig.height` interaction, and
#' fold the background colour into `dev.args`. We additionally set
#' `fig.cap = NA` to suppress knitr's "plot of chunk <label>" caption
#' fallback (and the surrounding `<div class="figure">` wrapper), which a
#' native pkgdown article does not show.
#'
#' pkgdown is required: articles are a pkgdown concept, so anyone
#' precompiling one should have it installed. We error rather than fall
#' back to hard-coded values that could silently drift from pkgdown.
#'
#' @return A named list suitable for `do.call(knitr::opts_chunk$set, .)`.
#' @noRd
pkgdown_fig_opts <- function() {
      if (!requireNamespace("pkgdown", quietly = TRUE)) {
            stop(
                  "Package 'pkgdown' is required to precompile articles, so the\n",
                  "baked-in figures match how pkgdown renders native articles\n",
                  "(resolution, retina, device). Install it with\n",
                  'install.packages("pkgdown"), or move this document out of\n',
                  "articles/ to precompile it as a plain vignette.",
                  call. = FALSE
            )
      }

      figures <- pkgdown::fig_settings()

      opts <- list()

      # Device. pkgdown renders with ragg::agg_png. knitr's corresponding
      # built-in device alias is "ragg_png" (underscore), which it resolves to
      # ragg::agg_png -- but ONLY if ragg is installed. We must NOT pass the
      # bare "agg_png" (knitr can't resolve it; the knit errors), and we must
      # not force "ragg_png" when ragg is absent (also errors). So: request
      # ragg_png only when ragg is available; otherwise leave `dev` unset and
      # let knitr use its default raster device, which still honors dpi and
      # fig.retina -- the levers that actually drive resolution parity.
      #
      # We deliberately do NOT thread pkgdown's `dev.args`/`bg` through. Those
      # are consumed by pkgdown's own device-invocation path, not by a plain
      # knit; passing bg = NA to knitr's device triggers a "mode(bg) differs"
      # warning (and is rejected outright by some devices). The visible
      # resolution parity does not depend on them.
      if (requireNamespace("ragg", quietly = TRUE)) {
            opts$dev <- "ragg_png"
      }

      # Resolution. fig.retina is the lever that gives native pkgdown figures
      # their 2x crispness; its absence is why a plain knit looks lower-res.
      # These are inert defaults: a chunk that doesn't set them inherits them,
      # and a chunk that does overrides cleanly.
      opts$dpi        <- figures$dpi
      opts$fig.retina <- figures$fig.retina

      # Default WIDTH only. We set pkgdown's default fig.width (so a chunk that
      # specifies no size still fills the pkgdown column), but we deliberately
      # do NOT set fig.height or fig.asp.
      #
      # fig.asp is the trap: in knitr, setting fig.asp RECOMPUTES fig.height as
      # fig.width * fig.asp for every chunk that doesn't itself set fig.asp =
      # NULL. So a document-wide fig.asp (pkgdown's default is 1.618) silently
      # overrides any per-chunk fig.height an author sets -- making all figures
      # come out at the same aspect ratio regardless of their chunk options.
      # fig.asp is an active transformer, not an inert default, so rawvignette
      # must not impose it. By setting only fig.width and leaving height/asp
      # alone, per-chunk fig.height (and fig.asp, and fig.dim) work normally;
      # a chunk that sets nothing falls back to knitr's default height.
      opts$fig.width <- figures$fig.width

      # Suppress knitr's "plot of chunk <label>" caption fallback and the
      # <div class="figure"> wrapper. NA means "no caption" without inventing
      # one; an author who wants captions can set fig.cap per-chunk.
      opts$fig.cap <- NA

      # Drop NULL entries so we don't hand opts_chunk$set() NULLs (it ignores
      # them anyway, but this keeps the list clean).
      opts[!vapply(opts, is.null, logical(1))]
}

#' Validate a vignette/article name.
#'
#' A name is valid if it is either a bare name (a top-level package
#' vignette, no `/`) or lives under `articles/` (a pkgdown article, at any
#' depth). Any other subdirectory is rejected: R's vignette machinery is
#' flat, so a non-`articles/` subdirectory could never be a package
#' vignette, and rawvignette enforces `articles/` as the single article
#' location by convention (matching usethis::use_article()).
#'
#' Errors with a clear message on an invalid name. Returns `nm` invisibly.
#' @noRd
validate_raw_vignette_name <- function(nm) {
      parts <- strsplit(nm, "/", fixed = TRUE)[[1]]

      if (length(parts) == 1L) {
            return(invisible(nm))           # bare name: a vignette
      }
      if (parts[1] == "articles") {
            return(invisible(nm))           # under articles/: an article
      }

      stop(
            "Invalid name: \"", nm, "\".\n",
            "Names must be either a bare vignette name (e.g. \"intro\") or ",
            "an article\nunder articles/ (e.g. \"articles/", parts[length(parts)],
            "\"). Other subdirectories\naren't supported: R's vignette ",
            "machinery is flat, so a non-articles/\nsubdirectory can't be a ",
            "package vignette. Did you mean \"articles/",
            parts[length(parts)], "\"?",
            call. = FALSE
      )
}
