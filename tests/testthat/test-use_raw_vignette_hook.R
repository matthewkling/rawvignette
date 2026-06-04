test_that("use_raw_vignette_hook installs a fresh hook when none exists", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create(".git")

            path <- suppressMessages(use_raw_vignette_hook())

            expect_true(file.exists(path))
            lines <- readLines(path)
            expect_true(startsWith(lines[1], "#!"))
            expect_true(any(grepl("check_raw_vignettes", lines)))
            expect_true(any(lines == "# >>> rawvignette pre-commit check >>>"))
            expect_true(any(lines == "# <<< rawvignette pre-commit check <<<"))
      })
})

test_that("use_raw_vignette_hook errors outside a git repo", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            expect_error(use_raw_vignette_hook(), "git repository")
      })
})

test_that("default on_collision errors when a hook already exists", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create(".git/hooks", recursive = TRUE)
            writeLines(c("#!/bin/sh", "echo existing"), ".git/hooks/pre-commit")

            expect_error(use_raw_vignette_hook(), "already exists")
            # Existing hook must be untouched by the failed call.
            lines <- readLines(".git/hooks/pre-commit")
            expect_true(any(grepl("echo existing", lines)))
            expect_false(any(grepl("check_raw_vignettes", lines)))
      })
})

test_that("on_collision = 'append' preserves existing hook content", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create(".git/hooks", recursive = TRUE)
            writeLines(c("#!/bin/sh", "echo existing readme hook"),
                       ".git/hooks/pre-commit")

            suppressMessages(use_raw_vignette_hook(on_collision = "append"))

            lines <- readLines(".git/hooks/pre-commit")
            # Original content survives...
            expect_true(any(grepl("echo existing readme hook", lines)))
            # ...and our block is added.
            expect_true(any(grepl("check_raw_vignettes", lines)))
            expect_equal(sum(lines == "# >>> rawvignette pre-commit check >>>"), 1L)
      })
})

test_that("append is idempotent: re-running replaces, doesn't duplicate", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create(".git/hooks", recursive = TRUE)
            writeLines(c("#!/bin/sh", "echo existing"), ".git/hooks/pre-commit")

            suppressMessages(use_raw_vignette_hook(on_collision = "append"))
            suppressMessages(use_raw_vignette_hook(on_collision = "append"))

            lines <- readLines(".git/hooks/pre-commit")
            # Exactly one managed block, and original still present once.
            expect_equal(sum(lines == "# >>> rawvignette pre-commit check >>>"), 1L)
            expect_equal(sum(grepl("echo existing", lines)), 1L)
      })
})

test_that("on_collision = 'overwrite' replaces the whole file", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create(".git/hooks", recursive = TRUE)
            writeLines(c("#!/bin/sh", "echo existing"), ".git/hooks/pre-commit")

            suppressMessages(use_raw_vignette_hook(on_collision = "overwrite"))

            lines <- readLines(".git/hooks/pre-commit")
            expect_false(any(grepl("echo existing", lines)))
            expect_true(any(grepl("check_raw_vignettes", lines)))
      })
})

test_that("remove deletes a rawvignette-only hook entirely", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create(".git")

            suppressMessages(use_raw_vignette_hook())
            expect_true(file.exists(".git/hooks/pre-commit"))

            suppressMessages(use_raw_vignette_hook(remove = TRUE))
            expect_false(file.exists(".git/hooks/pre-commit"))
      })
})

test_that("remove strips only our block from a shared hook", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create(".git/hooks", recursive = TRUE)
            writeLines(c("#!/bin/sh", "echo existing"), ".git/hooks/pre-commit")

            suppressMessages(use_raw_vignette_hook(on_collision = "append"))
            suppressMessages(use_raw_vignette_hook(remove = TRUE))

            expect_true(file.exists(".git/hooks/pre-commit"))
            lines <- readLines(".git/hooks/pre-commit")
            expect_true(any(grepl("echo existing", lines)))
            expect_false(any(grepl("check_raw_vignettes", lines)))
            expect_false(any(lines == "# >>> rawvignette pre-commit check >>>"))
      })
})

test_that("remove leaves a foreign hook untouched", {
      withr::with_tempdir({
            writeLines(c("Package: testpkg", "Version: 0.1.0"), "DESCRIPTION")
            dir.create(".git/hooks", recursive = TRUE)
            writeLines(c("#!/bin/sh", "echo not ours"), ".git/hooks/pre-commit")

            suppressMessages(use_raw_vignette_hook(remove = TRUE))

            expect_true(file.exists(".git/hooks/pre-commit"))
            expect_true(any(grepl("echo not ours",
                                  readLines(".git/hooks/pre-commit"))))
      })
})
