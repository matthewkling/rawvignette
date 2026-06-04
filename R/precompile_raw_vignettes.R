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
