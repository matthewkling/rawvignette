#' Scaffold a raw (precompiled) vignette or article
#'
#' Creates the infrastructure for a precompiled vignette or pkgdown
#' article. Whether you get a vignette or an article is determined by
#' `name`: a name under `articles/` (e.g. `"articles/benchmark"`)
#' scaffolds a web-only pkgdown article; any other name scaffolds a
#' package vignette.
#'
#' For a **vignette** (`name = "intro"`):
#' - `vignettes-raw/intro.Rmd` (the editable source)
#' - `^vignettes-raw$` in `.Rbuildignore`
#' - `vignettes/figures/` (where generated figures land; ships with pkg)
#'
#' For an **article** (`name = "articles/benchmark"`):
#' - `vignettes-raw/articles/benchmark.Rmd` (the editable source)
#' - `^vignettes-raw$` and `^vignettes/articles$` in `.Rbuildignore`
#'   (the latter keeps the rendered article and its figures out of the
#'   package tarball, so compute-heavy articles never burden CRAN)
#' - The skeleton omits the `vignette:` YAML block, so R does not treat
#'   it as a package vignette.
#'
#' If `vignettes/<name>.Rmd` already exists, it is migrated to
#' `vignettes-raw/<name>.Rmd` rather than overwritten.
#'
#' After running this, edit the skeleton, then call
#' [precompile_raw_vignettes()] to generate the shipped output.
#'
#' @param name Vignette or article name, without extension. Use an
#'   `articles/` prefix (e.g. `"articles/benchmark"`) to scaffold an
#'   article.
#' @param title Title. Defaults to the basename of `name`. Ignored if
#'   migrating an existing file (the existing title is preserved).
#' @return Invisibly, the path to the raw source file.
#' @export
use_raw_vignette <- function(name, title = NULL) {
      stopifnot(is.character(name), length(name) == 1L, nzchar(name))
      validate_raw_vignette_name(name)
      if (!file.exists("DESCRIPTION")) {
            stop("Run this from the package root (no DESCRIPTION found here).",
                 call. = FALSE)
      }

      is_article <- is_article_path(name)

      raw_dir <- "vignettes-raw"
      vig_dir <- "vignettes"
      dir.create(raw_dir, showWarnings = FALSE)
      dir.create(vig_dir, showWarnings = FALSE)

      src_path <- file.path(raw_dir, paste0(name, ".Rmd"))
      vig_path <- file.path(vig_dir, paste0(name, ".Rmd"))

      # Ensure nested source/output dirs exist (e.g. .../articles/).
      dir.create(dirname(src_path), recursive = TRUE, showWarnings = FALSE)
      dir.create(dirname(vig_path), recursive = TRUE, showWarnings = FALSE)

      # Vignettes use the shared flat figures dir; articles use rmarkdown's
      # default location beneath the article, created at knit time.
      if (!is_article) {
            dir.create(file.path(vig_dir, "figures"), showWarnings = FALSE)
      }

      # Guard against the likely vignette-to-article mistake: scaffolding an
      # article while a plain vignette exists at the non-article path. We
      # don't convert between the two; surface it rather than silently
      # writing a blank skeleton and orphaning the user's content.
      if (is_article) {
            base_vig_path <- file.path(vig_dir, paste0(basename(name), ".Rmd"))
            if (!file.exists(vig_path) && file.exists(base_vig_path)) {
                  stop(
                        "Found an existing vignette at ", base_vig_path, ".\n",
                        "rawvignette doesn't convert between vignettes and ",
                        "articles. If you\nintend to make it a precompiled ",
                        "article, move it to ", vig_path, "\nyourself first, ",
                        "then re-run this.",
                        call. = FALSE
                  )
            }
      }

      if (file.exists(src_path)) {
            message("Source file already exists: ", src_path)
      } else if (file.exists(vig_path)) {
            message("Migrating existing ", vig_path, " to ", src_path)
            file.rename(vig_path, src_path)
      } else {
            if (is.null(title)) title <- basename(name)
            writeLines(
                  vignette_skeleton(name, title, package_name(),
                                    article = is_article),
                  src_path
            )
            message("Created ", src_path)
      }

      add_to_rbuildignore("^vignettes-raw$")
      if (is_article) {
            add_to_rbuildignore("^vignettes/articles$")
      }

      message(
            "\nNext steps:\n",
            "  1. Edit ", src_path, "\n",
            "  2. Run: rawvignette::precompile_raw_vignettes()\n",
            "  3. Commit ", src_path, ", ", vig_path,
            if (is_article) ", and any new figures (web-only)."
            else ", and any new figures."
      )

      open_for_editing(src_path)

      invisible(src_path)
}
