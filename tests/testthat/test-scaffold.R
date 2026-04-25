test_that("use_raw_vignette creates expected structure in fresh package", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")

            use_raw_vignette("intro", title = "Introduction")

            expect_true(file.exists("vignettes-raw/intro.Rmd"))
            expect_true(file.exists("vignettes-raw/precompile.R"))
            expect_true(dir.exists("vignettes/figures"))
            expect_true(file.exists(".Rbuildignore"))

            buildignore <- readLines(".Rbuildignore")
            expect_true("^vignettes-raw$" %in% buildignore)

            src <- readLines("vignettes-raw/intro.Rmd")
            expect_true(any(grepl("Introduction", src)))
            expect_true(any(grepl("library\\(testpkg\\)", src)))
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

            use_raw_vignette("existing")

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
