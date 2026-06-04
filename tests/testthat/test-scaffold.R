test_that("use_raw_vignette creates expected structure in fresh package", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")

            suppressMessages(use_raw_vignette("intro", title = "Introduction"))

            expect_true(file.exists("vignettes-raw/intro.Rmd"))
            expect_true(dir.exists("vignettes/figures"))
            expect_true(file.exists(".Rbuildignore"))

            buildignore <- readLines(".Rbuildignore")
            expect_true("^vignettes-raw$" %in% buildignore)

            src <- readLines("vignettes-raw/intro.Rmd")
            expect_true(any(grepl("Introduction", src)))
            expect_true(any(grepl("library\\(testpkg\\)", src)))
      })
})

test_that("vignette skeleton contains a vignette: block", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")

            suppressMessages(use_raw_vignette("intro", title = "Introduction"))

            src <- readLines("vignettes-raw/intro.Rmd")
            expect_true(any(grepl("VignetteIndexEntry", src)))
            expect_true(any(grepl("VignetteEngine", src)))
      })
})

test_that("use_raw_vignette migrates existing vignette", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes")
            writeLines(c(
                  "---",
                  'title: "Existing"',
                  "---",
                  "",
                  "Original content"
            ), "vignettes/existing.Rmd")

            suppressMessages(use_raw_vignette("existing"))

            expect_false(file.exists("vignettes/existing.Rmd"))
            expect_true(file.exists("vignettes-raw/existing.Rmd"))
            src <- readLines("vignettes-raw/existing.Rmd")
            expect_true(any(grepl("Original content", src)))
      })
})

test_that("use_raw_vignette errors outside a package root", {
      withr::with_tempdir({
            expect_error(use_raw_vignette("intro"), "package root")
      })
})

# ---- Article scaffolding -------------------------------------------------

test_that("use_raw_vignette scaffolds an article under articles/", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")

            suppressMessages(use_raw_vignette("articles/benchmark", title = "Benchmark"))

            expect_true(file.exists("vignettes-raw/articles/benchmark.Rmd"))

            buildignore <- readLines(".Rbuildignore")
            expect_true("^vignettes-raw$" %in% buildignore)
            expect_true("^vignettes/articles$" %in% buildignore)
      })
})

test_that("article skeleton omits the vignette: block", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")

            suppressMessages(use_raw_vignette("articles/benchmark", title = "Benchmark"))

            src <- readLines("vignettes-raw/articles/benchmark.Rmd")
            # The defining property: R must NOT treat this as a vignette.
            expect_false(any(grepl("VignetteIndexEntry", src)))
            expect_false(any(grepl("VignetteEngine", src)))
            # Still a usable Rmd with title and library call.
            expect_true(any(grepl("Benchmark", src)))
            expect_true(any(grepl("library\\(testpkg\\)", src)))
      })
})

test_that("article title defaults to the basename, not the full path", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")

            suppressMessages(use_raw_vignette("articles/benchmark"))

            src <- readLines("vignettes-raw/articles/benchmark.Rmd")
            expect_true(any(grepl('title: "benchmark"', src, fixed = TRUE)))
            # Must not leak the articles/ prefix into the *title* line.
            # (The articles/ path legitimately appears in the regenerate-target
            # line near the bottom, so check the title line specifically.)
            title_line <- grep("^title:", src, value = TRUE)
            expect_false(any(grepl("articles/", title_line, fixed = TRUE)))
      })
})

test_that("use_raw_vignette migrates an existing vignette into a subdirectory", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes/articles", recursive = TRUE)
            writeLines(c(
                  "---",
                  'title: "Existing Article"',
                  "---",
                  "",
                  "Original article content"
            ), "vignettes/articles/existing.Rmd")

            suppressMessages(use_raw_vignette("articles/existing"))

            expect_false(file.exists("vignettes/articles/existing.Rmd"))
            expect_true(file.exists("vignettes-raw/articles/existing.Rmd"))
            src <- readLines("vignettes-raw/articles/existing.Rmd")
            expect_true(any(grepl("Original article content", src)))
      })
})

# ---- Orphaned-sibling warning on migration -------------------------------

test_that("migration warns about a data sibling left behind", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes/articles", recursive = TRUE)
            writeLines(c("---", 'title: "A"', "---", "", "Body"),
                       "vignettes/articles/bench.Rmd")
            writeLines("a,b\n1,2", "vignettes/articles/data.csv")

            msgs <- testthat::capture_messages(
                  use_raw_vignette("articles/bench"))
            expect_true(any(grepl("data\\.csv", msgs)))
            expect_true(any(grepl("remain in", msgs)))
            # The data file is NOT moved (we only warn).
            expect_true(file.exists("vignettes/articles/data.csv"))
      })
})

test_that("migration does not warn about other vignettes/structural dirs", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes/figures", recursive = TRUE)
            dir.create("vignettes/articles")
            writeLines(c("---", 'title: "V"', "---", "", "Body"),
                       "vignettes/intro.Rmd")
            writeLines(c("---", 'title: "O"', "---", "", "Body"),
                       "vignettes/other.Rmd")

            msgs <- testthat::capture_messages(use_raw_vignette("intro"))
            # other.Rmd, articles/, figures/ are not intro's data deps.
            expect_false(any(grepl("remain in", msgs)))
      })
})

test_that("migration warns about a top-level data file too", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes")
            writeLines(c("---", 'title: "V"', "---", "", "Body"),
                       "vignettes/intro.Rmd")
            writeLines("x", "vignettes/lookup.rds")

            msgs <- testthat::capture_messages(use_raw_vignette("intro"))
            expect_true(any(grepl("lookup\\.rds", msgs)))
      })
})

# ---- Name validation -----------------------------------------------------

test_that("use_raw_vignette rejects non-articles/ subdirectories", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")

            expect_error(use_raw_vignette("foo/my-article"), "Invalid name")
            # The error suggests the articles/ alternative.
            expect_error(use_raw_vignette("foo/my-article"), "articles/my-article")
      })
})

test_that("use_raw_vignette accepts nested articles", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")

            suppressMessages(use_raw_vignette("articles/advanced/deep", title = "Deep"))

            expect_true(file.exists("vignettes-raw/articles/advanced/deep.Rmd"))
            src <- readLines("vignettes-raw/articles/advanced/deep.Rmd")
            expect_false(any(grepl("VignetteIndexEntry", src)))
      })
})

test_that("use_raw_vignette errors on vignette-to-article collision", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes")
            # A plain vignette at the non-article path.
            writeLines(c("---", 'title: "Intro"', "---", "", "Body"),
                       "vignettes/intro.Rmd")

            # Trying to scaffold it as an article should error, not silently
            # write a blank skeleton and orphan the vignette.
            expect_error(use_raw_vignette("articles/intro"),
                         "doesn't convert")
            # The original vignette is left untouched.
            expect_true(file.exists("vignettes/intro.Rmd"))
            expect_false(file.exists("vignettes-raw/articles/intro.Rmd"))
      })
})
