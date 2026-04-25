#' Precompile raw vignettes
#'
#' Knits each `vignettes-raw/<n>.Rmd` to `vignettes/<n>.Rmd` and
#' injects a "do not edit" notice at the top of the output identifying
#' the source and how to regenerate.
#'
#' Each vignette's figures are written to `vignettes/figures/` with filenames
#' prefixed by the vignette name, preventing collisions when multiple
#' vignettes are precompiled. After a successful knit, figures belonging
#' to the vignette that weren't touched by the current run are treated as
#' orphans (e.g. left over from a renamed or deleted chunk) and deleted.
#'
#' Run from the package root.
#'
#' @param names Character vector of vignette names (without extension).
#'   If `NULL` (the default), all `.Rmd` files in `vignettes-raw/` are
#'   rebuilt.
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
            src_files <- list.files(raw_dir, pattern = "\\.Rmd$", full.names = FALSE)
            names <- tools::file_path_sans_ext(src_files)
      }

      if (length(names) == 0L) {
            message("No vignettes to precompile.")
            return(invisible(character()))
      }

      # Make figure paths from the source resolve relative to vignettes/
      old_base_dir <- knitr::opts_knit$get("base.dir")
      knitr::opts_knit$set(base.dir = normalizePath("vignettes", mustWork = TRUE))
      on.exit(knitr::opts_knit$set(base.dir = old_base_dir), add = TRUE)

      # Remember original fig.path so we can restore it after the loop
      old_fig_path <- knitr::opts_chunk$get("fig.path")
      on.exit(knitr::opts_chunk$set(fig.path = old_fig_path), add = TRUE)

      fig_dir <- file.path("vignettes", "figures")

      outputs <- character(length(names))
      for (i in seq_along(names)) {
            nm <- names[i]
            src <- file.path(raw_dir, paste0(nm, ".Rmd"))
            out <- file.path("vignettes", paste0(nm, ".Rmd"))

            if (!file.exists(src)) {
                  warning("Source not found, skipping: ", src, call. = FALSE)
                  next
            }

            # Per-vignette fig.path prefix to prevent collisions across vignettes
            knitr::opts_chunk$set(fig.path = paste0("figures/", nm, "-"))

            # Capture knit start time before knit runs so we can identify
            # figure files that were not touched by this run (i.e. orphans).
            # Subtract a small margin to handle coarse-mtime filesystems.
            knit_start <- Sys.time() - 1

            message("Knitting ", src, " -> ", out)
            knitr::knit(
                  input  = src,
                  output = out,
                  quiet  = quiet,
                  envir  = new.env(parent = globalenv())
            )
            inject_generated_notice(
                  path            = out,
                  source_path     = src,
                  precompile_path = file.path(raw_dir, "precompile.R")
            )

            # Clean up orphaned figures: files matching this vignette's prefix
            # that weren't written (or re-written) during this knit.
            if (dir.exists(fig_dir)) {
                  this_vignette_figs <- list.files(
                        fig_dir,
                        pattern    = paste0("^", nm, "-"),
                        full.names = TRUE
                  )
                  if (length(this_vignette_figs) > 0L) {
                        orphans <- this_vignette_figs[
                              file.mtime(this_vignette_figs) < knit_start
                        ]
                        if (length(orphans) > 0L) {
                              message("Removing ", length(orphans), " orphaned figure(s): ",
                                      paste(basename(orphans), collapse = ", "))
                              file.remove(orphans)
                        }
                  }
            }

            outputs[i] <- out
      }

      invisible(outputs[nzchar(outputs)])
}
