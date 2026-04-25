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

            precompile_raw_vignettes()

            expect_true(file.exists("vignettes/test.Rmd"))
            result <- readLines("vignettes/test.Rmd")
            expect_true(any(grepl("THIS FILE IS GENERATED", result)))
            expect_true(any(grepl("\\[1\\] 2", result)))  # knit output
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

            result <- check_raw_vignettes()
            expect_equal(result$status, "stale")
      })
})
