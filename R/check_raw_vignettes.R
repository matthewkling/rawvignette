#' Check whether raw vignettes/articles are in sync with their outputs
#'
#' Compares modification times of each `vignettes-raw/<path>.Rmd`
#' (recursively, so articles under `articles/` are included) against its
#' corresponding `vignettes/<path>.Rmd`. A source newer than its output
#' means the output is stale and should be regenerated with
#' [precompile_raw_vignettes()].
#'
#' @section What this catches:
#' The common case: you edited the raw source and forgot to precompile
#' before committing or releasing. mtime comparison reliably catches this.
#'
#' @section What this does not catch:
#' This check uses file modification times as a heuristic and will miss
#' several categories of true staleness. Treat its "fresh" verdict as a
#' weak guarantee, not a strong one. Specifically, it cannot detect:
#'
#' - **Changes to package source code.** If you edit `R/foo.R` so that
#'   `foo()` now returns different output, the captured output is
#'   logically stale even though the source `.Rmd` is unchanged.
#' - **Changes to data files.** Updates to `inst/extdata/`, `data/`, or
#'   any external file the source reads from will not be detected.
#' - **Changes to dependency package versions.** If a dependency changes
#'   behavior between rebuilds, the captured output may no longer reflect
#'   what the code now produces.
#' - **Touched-but-unchanged sources.** Opening and re-saving the source
#'   without editing it updates its mtime and falsely reports staleness.
#' - **Branch switches.** `git checkout` updates file mtimes, which can
#'   make everything look stale immediately after switching branches.
#'
#' For a robust freshness guarantee, the only reliable approach is to
#' run [precompile_raw_vignettes()] whenever any plausibly-relevant input
#' has changed.
#'
#' @return A data frame with columns `name`, `source`, `output`,
#'   `source_mtime`, `output_mtime`, and `status` (one of `"fresh"`,
#'   `"stale"`, or `"missing_output"`). Returned invisibly. Also emits
#'   a message summarizing any stale items.
#' @export
check_raw_vignettes <- function() {
      if (!file.exists("DESCRIPTION")) {
            stop("Run this from the package root (no DESCRIPTION found here).",
                 call. = FALSE)
      }

      raw_dir <- "vignettes-raw"
      if (!dir.exists(raw_dir)) {
            message("No `vignettes-raw/` directory found.")
            return(invisible(NULL))
      }

      # Recurse so articles/ (and any other subdirs) are included.
      src_files <- list.files(
            raw_dir,
            pattern    = "\\.Rmd$",
            full.names = FALSE,
            recursive  = TRUE
      )
      if (length(src_files) == 0L) {
            message("No raw vignettes found.")
            return(invisible(NULL))
      }

      names     <- tools::file_path_sans_ext(src_files)
      src_paths <- file.path(raw_dir, src_files)
      # Mirror the relative path into vignettes/ rather than flattening.
      out_paths <- file.path("vignettes", src_files)

      src_mtime <- file.mtime(src_paths)
      out_mtime <- file.mtime(out_paths)

      status <- ifelse(
            is.na(out_mtime), "missing_output",
            ifelse(src_mtime > out_mtime, "stale", "fresh")
      )

      result <- data.frame(
            name = names,
            source = src_paths,
            output = out_paths,
            source_mtime = src_mtime,
            output_mtime = out_mtime,
            status = status,
            stringsAsFactors = FALSE
      )

      stale <- result[result$status != "fresh", , drop = FALSE]
      if (nrow(stale) > 0L) {
            message(
                  "Stale precompiled vignette", if (nrow(stale) > 1L) "s" else "",
                  ":\n  - ", paste(stale$name, collapse = "\n  - "),
                  "\nRun rawvignette::precompile_raw_vignettes() to regenerate."
            )
      } else {
            message("All precompiled vignettes are fresh ",
                    "(by mtime; see ?check_raw_vignettes for caveats).")
      }

      invisible(result)
}
