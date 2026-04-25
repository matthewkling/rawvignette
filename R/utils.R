# Internal helpers. Not exported.

inject_generated_notice <- function(path, source_path, precompile_path) {
      lines <- readLines(path, warn = FALSE)
      yaml_delims <- which(lines == "---")
      insert_at <- if (length(yaml_delims) >= 2L) yaml_delims[2] else 0L

      notice <- c(
            "",
            "<!--",
            "  THIS FILE IS GENERATED. Do not edit by hand.",
            paste0("  Source: ", source_path),
            paste0("  Regenerate with: rawvignette::precompile_raw_vignettes()"),
            paste0("  (or run: Rscript ", precompile_path, ")"),
            "-->"
      )

      new_lines <- append(lines, notice, after = insert_at)
      writeLines(new_lines, path)
}

add_to_rbuildignore <- function(pattern) {
      path <- ".Rbuildignore"
      existing <- if (file.exists(path)) {
            readLines(path, warn = FALSE)
      } else {
            character()
      }
      if (!pattern %in% existing) {
            writeLines(c(existing, pattern), path)
            message("Added `", pattern, "` to .Rbuildignore")
      }
}

package_name <- function() {
      desc <- tryCatch(read.dcf("DESCRIPTION"), error = function(e) NULL)
      if (is.null(desc) || !"Package" %in% colnames(desc)) {
            return("yourpackage")
      }
      unname(desc[1, "Package"])
}

open_for_editing <- function(path) {
      if (!interactive()) return(invisible())
      if (identical(Sys.getenv("TESTTHAT"), "true")) return(invisible())

      if (requireNamespace("rstudioapi", quietly = TRUE) &&
          rstudioapi::isAvailable()) {
            rstudioapi::navigateToFile(path)
      } else {
            tryCatch(
                  utils::file.edit(path),
                  error = function(e) invisible()
            )
      }
      invisible()
}

vignette_skeleton <- function(name, title, pkg) {
      c(
            "---",
            paste0('title: "', title, '"'),
            'output: rmarkdown::html_vignette',
            "vignette: >",
            paste0("  %\\VignetteIndexEntry{", title, "}"),
            "  %\\VignetteEngine{knitr::rmarkdown}",
            "  %\\VignetteEncoding{UTF-8}",
            "---",
            "",
            "```{r setup, include = FALSE}",
            "knitr::opts_chunk$set(",
            "  collapse = TRUE,",
            '  comment  = "#>"',
            ")",
            "```",
            "",
            "```{r}",
            paste0("library(", pkg, ")"),
            "```",
            "",
            "Write vignette content here. This is the source — edit it freely.",
            "Run `rawvignette::precompile_raw_vignettes()` to regenerate the shipped",
            paste0("vignette at `vignettes/", name, ".Rmd`.")
      )
}

precompile_skeleton <- function() {
      c(
            "# Rebuild all precompiled vignettes for this package.",
            "# Run from the package root:",
            "#   Rscript vignettes-raw/precompile.R",
            "# Or interactively:",
            "#   rawvignette::precompile_raw_vignettes()",
            "",
            'if (requireNamespace("devtools", quietly = TRUE)) {',
            '  devtools::load_all(".")',
            "}",
            "",
            "rawvignette::precompile_raw_vignettes()"
      )
}
