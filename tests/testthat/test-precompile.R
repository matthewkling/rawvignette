test_that("inject_generated_notice adds notice after YAML", {
      path <- withr::local_tempfile()
      writeLines(c(
            "---",
            'title: "test"',
            "---",
            "",
            "Body text"
      ), path)

      inject_generated_notice(path, "vignettes-raw/test.Rmd")

      result <- readLines(path)
      expect_true(any(grepl("THIS FILE IS GENERATED", result)))
      # Notice should be after the closing YAML delimiter
      yaml_end <- which(result == "---")[2]
      notice_line <- which(grepl("THIS FILE IS GENERATED", result))
      expect_gt(notice_line, yaml_end)
})

test_that("inject_generated_notice handles file with no YAML", {
      path <- withr::local_tempfile()
      writeLines(c("Just some body text"), path)

      inject_generated_notice(path, "src.Rmd")

      result <- readLines(path)
      expect_true(any(grepl("THIS FILE IS GENERATED", result)))
})

test_that("inject_generated_notice spells the package name correctly", {
      path <- withr::local_tempfile()
      writeLines(c("---", 'title: "test"', "---", "", "Body"), path)

      inject_generated_notice(path, "vignettes-raw/test.Rmd")

      result <- readLines(path)
      # Regression guard for the historical "rawwvignette" double-w typo.
      expect_false(any(grepl("rawwvignette", result)))
      expect_true(any(grepl("rawvignette", result)))
})

test_that("add_to_rbuildignore is idempotent", {
      withr::with_tempdir({
            add_to_rbuildignore("^vignettes-raw$")
            add_to_rbuildignore("^vignettes-raw$")  # second call should no-op
            content <- readLines(".Rbuildignore")
            expect_equal(sum(content == "^vignettes-raw$"), 1L)
      })
})

test_that("is_article_path recognizes the articles/ subtree", {
      expect_true(is_article_path("articles/benchmark"))
      expect_true(is_article_path("articles/sub/deep"))

      expect_false(is_article_path("intro"))
      expect_false(is_article_path("benchmark"))
      # Bare "articles" with no file beneath it is not an article path.
      expect_false(is_article_path("articles"))
      # A vignette merely named with an articles-like prefix isn't one.
      expect_false(is_article_path("articles-overview"))
})
