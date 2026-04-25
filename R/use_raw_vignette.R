#' Scaffold a raw (precompiled) vignette
#'
#' Creates the infrastructure for a precompiled vignette:
#' - `vignettes-raw/<n>.Rmd` (the editable source)
#' - An entry in `.Rbuildignore` for `vignettes-raw/`
#' - `vignettes/figures/` directory (where generated figures will land)
#'
#' If `vignettes/<n>.Rmd` already exists (e.g. from a previous
#' `usethis::use_vignette()` call), it is migrated to `vignettes-raw/<n>.Rmd`
#' rather than overwritten.
#'
#' After running this, edit the skeleton in `vignettes-raw/<n>.Rmd`, then
#' call [precompile_raw_vignettes()] to generate the shipped `vignettes/<n>.Rmd`.
#'
#' In interactive sessions, the source file is opened for editing (in RStudio
#' if available, otherwise via `utils::file.edit()`).
#'
#' @param name Vignette name, without extension.
#' @param title Vignette title. Defaults to `name`. Ignored if migrating
#'   an existing vignette (the existing title is preserved).
#' @return Invisibly, the path to the raw source file.
#' @export
use_raw_vignette <- function(name, title = NULL) {
      stopifnot(is.character(name), length(name) == 1L, nzchar(name))
      if (!file.exists("DESCRIPTION")) {
            stop("Run this from the package root (no DESCRIPTION found here).",
                 call. = FALSE)
      }

      raw_dir <- "vignettes-raw"
      vig_dir <- "vignettes"
      dir.create(raw_dir, showWarnings = FALSE)
      dir.create(vig_dir, showWarnings = FALSE)
      dir.create(file.path(vig_dir, "figures"), showWarnings = FALSE)

      src_path <- file.path(raw_dir, paste0(name, ".Rmd"))
      vig_path <- file.path(vig_dir, paste0(name, ".Rmd"))

      if (file.exists(src_path)) {
            message("Source file already exists: ", src_path)
      } else if (file.exists(vig_path)) {
            message("Migrating existing ", vig_path, " to ", src_path)
            file.rename(vig_path, src_path)
      } else {
            if (is.null(title)) title <- name
            writeLines(vignette_skeleton(name, title, package_name()), src_path)
            message("Created ", src_path)
      }

      add_to_rbuildignore("^vignettes-raw$")

      message(
            "\nNext steps:\n",
            "  1. Edit ", src_path, "\n",
            "  2. Run: rawvignette::precompile_raw_vignettes()\n",
            "  3. Commit ", src_path, ", ", vig_path, ", and any new figures."
      )

      open_for_editing(src_path)

      invisible(src_path)
}
