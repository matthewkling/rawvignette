#' Install a pre-commit hook that checks precompiled-vignette freshness
#'
#' Writes a git `pre-commit` hook that runs [check_raw_vignettes()] and
#' aborts the commit if any precompiled vignette or article is stale
#' (its `vignettes-raw/` source is newer than its `vignettes/` output).
#' This catches the common slip of editing a raw source and forgetting to
#' run [precompile_raw_vignettes()] before committing.
#'
#' The hook is a plain shell script written to `.git/hooks/pre-commit`,
#' in the same spirit as the README hook installed by
#' `usethis::use_readme_rmd()`. It does **not** depend on the `precommit`
#' framework (no Python).
#'
#' @section Scope and limitations:
#' This is a *local* convenience, not a guarantee:
#' - It lives in `.git/hooks/`, which is not version-controlled, so it
#'   does not propagate to collaborators or survive a fresh clone. Each
#'   clone must run this again.
#' - Like [check_raw_vignettes()], it compares modification times and so
#'   only catches *source-edited-but-not-reknitted*. It cannot detect
#'   staleness caused by changes to package code, data, or dependencies,
#'   and may false-positive right after a `git checkout` (which rewrites
#'   mtimes). Use `git commit --no-verify` to bypass in that case.
#' - The only robust freshness guarantee is to re-run
#'   [precompile_raw_vignettes()] before a release.
#'
#' @section Collision handling:
#' Git supports a single `pre-commit` hook file, which may already be in
#' use (e.g. the README hook from `usethis::use_readme_rmd()`). The
#' `on_collision` argument controls what happens when
#' `.git/hooks/pre-commit` already exists:
#' - `"error"` (default): do nothing and stop, with a message explaining
#'   the `"append"` and `"overwrite"` alternatives.
#' - `"append"`: add this check to the existing hook, wrapped in
#'   `rawvignette` sentinel markers so it can be updated or removed later
#'   without disturbing the rest of the file. Re-running replaces the
#'   marked block rather than duplicating it.
#' - `"overwrite"`: replace the entire hook file with a fresh one
#'   containing only this check. Destroys any existing hook content.
#'
#' If no hook exists yet, a new one is written regardless of
#' `on_collision`.
#'
#' @param on_collision One of `"error"`, `"append"`, `"overwrite"`.
#'   See Collision handling.
#' @param remove If `TRUE`, remove the `rawvignette` hook instead of
#'   installing it. If the hook was appended (sentinel markers present),
#'   only the marked block is stripped, leaving the rest intact; if that
#'   leaves an empty hook, the file is deleted. If the whole file is a
#'   rawvignette-only hook, it is deleted. Other files are left untouched.
#' @return Invisibly, the path to the hook file (or `NULL` if nothing was
#'   written/removed).
#' @export
use_raw_vignette_hook <- function(on_collision = c("error", "append", "overwrite"),
                                  remove = FALSE) {
      on_collision <- match.arg(on_collision)

      if (!file.exists("DESCRIPTION")) {
            stop("Run this from the package root (no DESCRIPTION found here).",
                 call. = FALSE)
      }
      if (!dir.exists(".git")) {
            stop("No `.git/` directory found. Is this a git repository?",
                 call. = FALSE)
      }

      hook_dir  <- file.path(".git", "hooks")
      hook_path <- file.path(hook_dir, "pre-commit")

      if (remove) {
            return(invisible(remove_hook(hook_path)))
      }

      dir.create(hook_dir, recursive = TRUE, showWarnings = FALSE)

      if (!file.exists(hook_path)) {
            writeLines(full_hook_script(), hook_path)
            Sys.chmod(hook_path, mode = "0755")
            message("Installed pre-commit hook at ", hook_path)
            return(invisible(hook_path))
      }

      # A hook already exists -> consult on_collision.
      switch(on_collision,
             error = stop(
                   "A pre-commit hook already exists at ", hook_path, ".\n",
                   "rawvignette won't overwrite it by default. Choose one:\n",
                   '  - use_raw_vignette_hook(on_collision = "append")  ',
                   "# add the check to the existing hook\n",
                   '  - use_raw_vignette_hook(on_collision = "overwrite") ',
                   "# replace the existing hook entirely\n",
                   "Or add the check manually; see ?use_raw_vignette_hook.",
                   call. = FALSE
             ),
             append = {
                   append_hook_block(hook_path)
                   Sys.chmod(hook_path, mode = "0755")
                   message("Appended rawvignette check to existing hook at ",
                           hook_path)
                   invisible(hook_path)
             },
             overwrite = {
                   writeLines(full_hook_script(), hook_path)
                   Sys.chmod(hook_path, mode = "0755")
                   message("Overwrote pre-commit hook at ", hook_path)
                   invisible(hook_path)
             }
      )
}

# ---- Internal hook helpers (not exported) --------------------------------

# Sentinel markers delimiting the rawvignette-managed block within a hook.
hook_begin_marker <- "# >>> rawvignette pre-commit check >>>"
hook_end_marker   <- "# <<< rawvignette pre-commit check <<<"

# The R one-liner the hook runs. Exits non-zero (aborting the commit) if any
# precompiled vignette/article is stale. check_raw_vignettes() emits its own
# explanatory message; here we just translate "any stale" into an error.
hook_r_command <- function() {
      paste0(
            "Rscript -e ",
            shQuote(paste0(
                  "res <- rawvignette::check_raw_vignettes(); ",
                  "if (!is.null(res) && any(res$status != 'fresh')) ",
                  "quit(status = 1)"
            ))
      )
}

# The body lines that do the check (no shebang) -- shared by full and
# appended forms.
hook_body <- function() {
      c(
            hook_begin_marker,
            "# Managed by rawvignette::use_raw_vignette_hook(). Edit between the",
            "# markers at your own risk; use_raw_vignette_hook(remove = TRUE) strips it.",
            hook_r_command(),
            hook_end_marker
      )
}

# A complete, standalone hook file (shebang + body).
full_hook_script <- function() {
      c("#!/bin/sh", "", hook_body())
}

# Append the rawvignette block to an existing hook. If a previous block is
# present (identified by the sentinels), replace it in place rather than
# adding a second copy.
append_hook_block <- function(hook_path) {
      lines <- readLines(hook_path, warn = FALSE)
      stripped <- strip_hook_block(lines)

      # Ensure the existing file has a shebang; if not, give it one so the
      # appended shell remains executable as /bin/sh.
      if (length(stripped) == 0L || !startsWith(stripped[1], "#!")) {
            stripped <- c("#!/bin/sh", stripped)
      }

      writeLines(c(stripped, "", hook_body()), hook_path)
      invisible(hook_path)
}

# Remove the rawvignette block from a vector of hook lines. Returns the
# remaining lines (with any trailing blank padding left as-is).
strip_hook_block <- function(lines) {
      b <- which(lines == hook_begin_marker)
      e <- which(lines == hook_end_marker)
      if (length(b) == 0L || length(e) == 0L) {
            return(lines)                 # no managed block present
      }
      # Use the first begin and the last end to be robust to oddities.
      b <- b[1]; e <- e[length(e)]
      if (e < b) return(lines)
      # Also drop a single blank separator line immediately before the block,
      # if we added one during append.
      drop_from <- if (b > 1L && lines[b - 1L] == "") b - 1L else b
      lines[-(drop_from:e)]
}

# Remove the hook. Three cases:
#  - file is exactly a rawvignette-only hook  -> delete the file
#  - file contains a rawvignette block among other content -> strip block
#  - file has no rawvignette block            -> leave untouched, message
remove_hook <- function(hook_path) {
      if (!file.exists(hook_path)) {
            message("No pre-commit hook to remove at ", hook_path)
            return(NULL)
      }
      lines <- readLines(hook_path, warn = FALSE)
      if (!any(lines == hook_begin_marker)) {
            message("No rawvignette block found in ", hook_path,
                    "; leaving it untouched.")
            return(NULL)
      }

      remaining <- strip_hook_block(lines)
      # If all that's left is a shebang and blank lines, delete the file.
      meaningful <- remaining[nzchar(trimws(remaining)) &
                                    !startsWith(remaining, "#!")]
      if (length(meaningful) == 0L) {
            file.remove(hook_path)
            message("Removed rawvignette pre-commit hook ", hook_path)
      } else {
            writeLines(remaining, hook_path)
            Sys.chmod(hook_path, mode = "0755")
            message("Stripped rawvignette block from ", hook_path,
                    " (other hook content preserved).")
      }
      invisible(hook_path)
}
