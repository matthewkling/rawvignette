test_that("precompile_raw_vignettes knits and injects notice", {
      skip_if_not_installed("knitr")

      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw")
            dir.create("vignettes")

            writeLines(c(
                  "---",
                  'title: "Test"',
                  "---",
                  "",
                  "```{r}",
                  "1 + 1",
                  "```"
            ), "vignettes-raw/test.Rmd")

            suppressMessages(precompile_raw_vignettes())

            expect_true(file.exists("vignettes/test.Rmd"))
            result <- readLines("vignettes/test.Rmd")
            expect_true(any(grepl("THIS FILE IS GENERATED", result)))
            expect_true(any(grepl("\\[1\\] 2", result)))  # knit output
      })
})

test_that("generated notice spells the package name correctly", {
      skip_if_not_installed("knitr")

      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw")
            dir.create("vignettes")
            writeLines(c("---", 'title: "Test"', "---", "", "Body"),
                       "vignettes-raw/test.Rmd")

            suppressMessages(precompile_raw_vignettes())

            result <- readLines("vignettes/test.Rmd")
            expect_true(any(grepl("rawvignette::precompile_raw_vignettes", result)))
            # Guard against the historical "rawwvignette" typo regressing.
            expect_false(any(grepl("rawwvignette", result)))
      })
})

test_that("check_raw_vignettes detects stale outputs", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw")
            dir.create("vignettes")

            writeLines("source", "vignettes-raw/a.Rmd")
            writeLines("output", "vignettes/a.Rmd")
            # Make output older than source
            Sys.setFileTime("vignettes/a.Rmd", Sys.time() - 60)

            result <- suppressMessages(check_raw_vignettes())
            expect_equal(result$status, "stale")
      })
})

# ---- Figure routing ------------------------------------------------------

test_that("vignette figures land in flat vignettes/figures/ with name prefix", {
      skip_if_not_installed("knitr")

      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw")
            dir.create("vignettes")

            writeLines(c(
                  "---",
                  'title: "Plotting"',
                  "---",
                  "",
                  "```{r myplot}",
                  "plot(1:10)",
                  "```"
            ), "vignettes-raw/plotme.Rmd")

            suppressMessages(precompile_raw_vignettes())

            expect_true(dir.exists("vignettes/figures"))
            figs <- list.files("vignettes/figures")
            expect_true(length(figs) > 0L)
            # Figure filenames carry the vignette-name prefix.
            expect_true(all(grepl("^plotme-", figs)))
      })
})

test_that("article precompiles to vignettes/articles/ and keeps figures in subtree", {
      skip_if_not_installed("knitr")

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

            # Output mirrored into vignettes/articles/
            expect_true(file.exists("vignettes/articles/benchmark.Rmd"))
            result <- readLines("vignettes/articles/benchmark.Rmd")
            expect_true(any(grepl("THIS FILE IS GENERATED", result)))

            # Article figures live under the build-ignored articles/ subtree,
            # NOT in the shipped vignettes/figures/ directory.
            article_figs <- list.files("vignettes/articles", recursive = TRUE,
                                       pattern = "\\.(png|svg|jpg|jpeg)$")
            expect_true(length(article_figs) > 0L)

            shipped_figs <- if (dir.exists("vignettes/figures")) {
                  list.files("vignettes/figures")
            } else {
                  character()
            }
            expect_false(any(grepl("benchmark", shipped_figs)))
      })
})

test_that("precompile rebuilds a mixed tree of vignettes and articles", {
      skip_if_not_installed("knitr")

      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw/articles", recursive = TRUE)
            dir.create("vignettes")

            writeLines(c("---", 'title: "V"', "---", "", "```{r}", "1+1", "```"),
                       "vignettes-raw/intro.Rmd")
            writeLines(c("---", 'title: "A"', "---", "", "```{r}", "2+2", "```"),
                       "vignettes-raw/articles/extra.Rmd")

            out <- suppressMessages(precompile_raw_vignettes())

            expect_true(file.exists("vignettes/intro.Rmd"))
            expect_true(file.exists("vignettes/articles/extra.Rmd"))
            expect_length(out, 2L)
      })
})

test_that("check_raw_vignettes recurses into articles/", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create("vignettes-raw/articles", recursive = TRUE)
            dir.create("vignettes/articles", recursive = TRUE)

            writeLines("source", "vignettes-raw/articles/a.Rmd")
            writeLines("output", "vignettes/articles/a.Rmd")
            Sys.setFileTime("vignettes/articles/a.Rmd", Sys.time() - 60)

            result <- suppressMessages(check_raw_vignettes())
            expect_true("articles/a" %in% result$name)
            expect_equal(result$status[result$name == "articles/a"], "stale")
      })
})
