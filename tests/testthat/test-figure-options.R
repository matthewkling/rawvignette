# Tests for the pkgdown figure-option handling added to the article branch of
# precompile_raw_vignettes() (and its helper pkgdown_fig_opts()).
#
# These focus on observable behavior, matching the style of test-precompile.R:
#   1. Captions: a precompiled article must NOT carry knitr's "plot of chunk"
#      caption fallback or the <div class="figure"> wrapper (the original bug).
#   2. No leakage: precompiling must leave global knitr chunk options as it
#      found them, and article figure settings must not bleed into a vignette
#      built in the same call.
#   3. pkgdown required: pkgdown_fig_opts() errors clearly when pkgdown is
#      absent (articles are a pkgdown concept; we error rather than guess).

# ---- Captions ------------------------------------------------------------

test_that("precompiled article has no auto figure captions or figure div", {
      skip_if_not_installed("knitr")
      skip_if_not_installed("pkgdown")

      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw/articles", recursive = TRUE)
            dir.create("vignettes")

            writeLines(c(
                  "---",
                  'title: "Benchmark"',
                  "---",
                  "",
                  "```{r bench}",
                  "plot(1:10)",
                  "```"
            ), "vignettes-raw/articles/benchmark.Rmd")

            suppressMessages(precompile_raw_vignettes())

            result <- readLines("vignettes/articles/benchmark.Rmd")
            # knitr's fallback caption text for an uncaptioned chunk.
            expect_false(any(grepl("plot of chunk", result, fixed = TRUE)))
            # ...and the wrapper it emits alongside that caption.
            expect_false(any(grepl('<div class="figure"', result, fixed = TRUE)))
      })
})

test_that("a per-chunk fig.cap still produces a caption (defaults don't force it off)", {
      skip_if_not_installed("knitr")
      skip_if_not_installed("pkgdown")

      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw/articles", recursive = TRUE)
            dir.create("vignettes")

            writeLines(c(
                  "---",
                  'title: "Benchmark"',
                  "---",
                  "",
                  '```{r bench, fig.cap="My real caption"}',
                  "plot(1:10)",
                  "```"
            ), "vignettes-raw/articles/benchmark.Rmd")

            suppressMessages(precompile_raw_vignettes())

            result <- readLines("vignettes/articles/benchmark.Rmd")
            # The author's explicit caption must survive (our fig.cap = NA is
            # only a default; per-chunk settings win).
            expect_true(any(grepl("My real caption", result, fixed = TRUE)))
      })
})

# ---- No leakage / no bleed ----------------------------------------------

test_that("precompiling an article restores global chunk options", {
      skip_if_not_installed("knitr")
      skip_if_not_installed("pkgdown")

      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw/articles", recursive = TRUE)
            dir.create("vignettes")

            writeLines(c(
                  "---", 'title: "A"', "---", "",
                  "```{r}", "plot(1:10)", "```"
            ), "vignettes-raw/articles/a.Rmd")

            keys <- c("dev", "dpi", "fig.retina", "fig.width", "fig.cap")
            before <- knitr::opts_chunk$get(keys)

            suppressMessages(precompile_raw_vignettes())

            after <- knitr::opts_chunk$get(keys)
            expect_identical(after, before)
      })
})

test_that("article figure settings do not bleed into a vignette in the same call", {
      skip_if_not_installed("knitr")
      skip_if_not_installed("pkgdown")

      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw/articles", recursive = TRUE)
            dir.create("vignettes")

            # Article first (alphabetically the article sorts under "articles/",
            # but build order follows list.files; include both and assert the
            # vignette output is unaffected regardless of order).
            writeLines(c(
                  "---", 'title: "A"', "---", "",
                  "```{r aplot}", "plot(1:10)", "```"
            ), "vignettes-raw/articles/a.Rmd")
            writeLines(c(
                  "---", 'title: "V"', "---", "",
                  "```{r vplot}", "plot(1:10)", "```"
            ), "vignettes-raw/v.Rmd")

            suppressMessages(precompile_raw_vignettes())

            # The vignette's figure must live in the flat shipped figures/ dir
            # with the vignette prefix -- i.e. it went through the vignette
            # branch, not contaminated by article (_files) routing.
            expect_true(dir.exists("vignettes/figures"))
            vig_figs <- list.files("vignettes/figures")
            expect_true(any(grepl("^v-", vig_figs)))

            # And the article's figure did NOT land in the shipped figures dir.
            expect_false(any(grepl("^a-", vig_figs)))
      })
})

# ---- pkgdown required ----------------------------------------------------

# Testing the pkgdown-absent path is awkward: pkgdown is almost certainly
# INSTALLED in the dev/CI environment, and reliably faking its absence means
# intercepting requireNamespace(), a base function. Mocking base functions is
# fragile (and testthat may itself call requireNamespace), so the most robust
# approach is to make pkgdown_fig_opts() consult an internal seam we can stub.
#
# OPTION A (recommended): introduce a tiny internal indirection in the package,
# e.g.
#
#     has_pkgdown <- function() requireNamespace("pkgdown", quietly = TRUE)
#
# and have pkgdown_fig_opts() call has_pkgdown(). Then this test is clean:
#
#     test_that("pkgdown_fig_opts errors clearly when pkgdown is unavailable", {
#           testthat::local_mocked_bindings(has_pkgdown = function() FALSE)
#           expect_error(pkgdown_fig_opts(),
#                        "pkgdown.*required", ignore.case = TRUE)
#     })
#
# OPTION B (no code change): only assert the happy path, and treat the error
# branch as covered by inspection. Given the branch is a single guarded stop()
# with a static message, Option B is defensible, but Option A is cheap and
# makes the decision ("error, don't fall back") regression-proof.
#
# Leaving this as a documented stub rather than shipping a mock that may not
# work in your testthat version. Wire up Option A if you want the coverage.

test_that("pkgdown_fig_opts returns figure options when pkgdown is present", {
      skip_if_not_installed("pkgdown")

      opts <- pkgdown_fig_opts()
      expect_type(opts, "list")
      # The caption suppression is ours, not pkgdown's -- always present.
      expect_true("fig.cap" %in% names(opts))
      expect_true(is.na(opts$fig.cap))
      # fig.retina is the lever for resolution parity; pkgdown sets it.
      # (If this fails, fig_settings() may need a pkgdown context set up
      # first -- see notes accompanying pkgdown_fig_opts().)
      expect_true("fig.retina" %in% names(opts))
      # fig.asp and fig.height must NOT be imposed: a document-wide fig.asp
      # would recompute every chunk's height and override per-chunk fig.height.
      # Only an inert default fig.width is set for sizing.
      expect_false("fig.asp" %in% names(opts))
      expect_false("fig.height" %in% names(opts))
      expect_true("fig.width" %in% names(opts))
})

test_that("per-chunk fig.height is respected (fig.asp default not imposed)", {
      skip_if_not_installed("knitr")
      skip_if_not_installed("pkgdown")

      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw/articles", recursive = TRUE)
            dir.create("vignettes")

            # Two chunks, same width, very different per-chunk heights. If a
            # document-wide fig.asp were imposed, both would be forced to the
            # same height (fig.width * asp) and the PNGs would match. They must
            # not.
            writeLines(c(
                  "---", 'title: "Dims"', "---", "",
                  "```{r short, fig.width=5, fig.height=2}", "plot(1:10)", "```",
                  "",
                  "```{r tall, fig.width=5, fig.height=8}", "plot(1:10)", "```"
            ), "vignettes-raw/articles/dims.Rmd")

            suppressMessages(precompile_raw_vignettes("articles/dims"))

            fig_dir <- file.path("vignettes", "articles", "dims_files",
                                 "figure-html")
            pngs <- list.files(fig_dir, pattern = "\\.png$", full.names = TRUE)
            expect_length(pngs, 2L)

            # Read PNG pixel height from the IHDR chunk (bytes 21-24, big-endian)
            # to avoid depending on the png package.
            png_height <- function(path) {
                  raw <- readBin(path, "raw", n = 24L)
                  hi <- as.integer(raw[21:24])
                  sum(hi * 256^(3:0))
            }
            heights <- vapply(sort(pngs), png_height, numeric(1))
            # The "tall" figure (fig.height=8) must be meaningfully taller than
            # the "short" one (fig.height=2). If fig.asp were imposed they'd be
            # equal.
            expect_gt(max(heights), min(heights) * 1.5)
      })
})
