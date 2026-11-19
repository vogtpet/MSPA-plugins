## ---------------------------------------------------------------------------
## Regression test for the processing callback.
##
## The job runs in a later::later() callback, where no default reactive domain
## is active. removeModal()/showModal() and shinyjs must therefore be given the
## session explicitly (or must not be used at all). This test starts the server
## with a stubbed mspa_process() and runs the callback.
##
## Usage: Rscript tests/app-callback-test.R
## ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
here <- if (length(file_arg) == 1L && nzchar(file_arg)) {
  dirname(normalizePath(file_arg))
} else {
  normalizePath("tests", mustWork = FALSE)
}
app_dir <- normalizePath(file.path(here, ".."))
options(rmspa.app_dir = app_dir)

suppressPackageStartupMessages(library(shiny))
source(file.path(app_dir, "app.R"), local = TRUE)
app <- shinyApp(ui, server)

## The server uses the runtime object from its enclosing environment; make it
## look as if the binary had been found.
runtime <- list(ok = TRUE, target = "test", binary = "/nonexistent/mspa",
                version = "2.4", detail = "")

## Replace the real MSPA call with a stub that returns immediately.
stub_result <- list(ok = TRUE, message = "ok", outfile = "",
                    disk = FALSE, params = list())
mspa_process <- function(input, outdir, ...) {
  stub_result$outfile <- file.path(outdir, "stub.tif")
  stub_result
}

outdir <- file.path(path.expand("~"), ".rmspa-callback-test")
dir.create(outdir, showWarnings = FALSE)
on.exit(unlink(outdir, recursive = TRUE, force = TRUE), add = TRUE)

failed <- FALSE
check <- function(what, condition, detail = "") {
  if (isTRUE(condition)) {
    cat("ok    ", what, "\n", sep = "")
  } else {
    failed <<- TRUE
    cat("FAIL  ", what, if (nzchar(detail)) paste0(": ", detail) else "", "\n",
        sep = "")
  }
}

## The callback runs outside the reactive domain in a real session, so the
## modal helpers must pass the session explicitly (see app.R).
app_src <- readLines(file.path(app_dir, "app.R"))
check("modal helpers pass the session",
      any(grepl("showModal(ui, session = session)", app_src, fixed = TRUE)) &&
      any(grepl("removeModal(session = session)", app_src, fixed = TRUE)))
check("no bare removeModal() calls",
      !any(grepl("removeModal()", app_src, fixed = TRUE)))

testServer(app, {
  ## The job callback runs without a default reactive domain in a real session.
  ## Run it that way here, so any reactive read inside the callback fails.
  callback_error <- NULL
  wait_for <- function(condition, timeout = 5) {
    deadline <- Sys.time() + timeout
    while (!isTRUE(condition()) && Sys.time() < deadline &&
           is.null(callback_error)) {
      tryCatch(
        shiny::withReactiveDomain(NULL, later::run_now(0.2)),
        error = function(e) callback_error <<- conditionMessage(e)
      )
      session$flushReact()
    }
    isTRUE(condition())
  }

  session$setInputs(
    btnSelectFile = list(datapath = file.path(app_dir, "examples/input.tif"),
                         name = "input.tif"),
    encoding = "gtb"
  )
  session$flushReact()
  check("input accepted", isTRUE(state$info$ok),
        if (is.null(state$info)) "no input info" else state$info$message)

  session$setInputs(selectFolder = list(root = "Home", path = ".rmspa-callback-test"))
  session$setInputs(btnStart = 1)
  session$flushReact()

  check("callback completed", wait_for(function() !is.null(state$last)))
  check("callback used no reactive values", is.null(callback_error),
        callback_error %||% "")
  check("busy flag reset", identical(state$busy, FALSE))
  if (!is.null(state$last)) {
    check("output recorded", identical(basename(state$last$outfile), "stub.tif"))
  }

  ## Failure path: the job must still reset the state and close the modal.
  stub_result <<- list(ok = FALSE, message = "simulated failure",
                       outfile = NULL, disk = FALSE, params = list())
  state$last <- NULL
  session$setInputs(btnStart = 2)
  session$flushReact()
  wait_for(function() identical(state$busy, FALSE))
  check("failure path completed",
        identical(state$busy, FALSE) && is.null(state$last))
  check("failure path used no reactive values", is.null(callback_error),
        callback_error %||% "")
})

cat("\n")
if (failed) {
  cat("FAILED\n")
  quit(status = 1L)
}
cat("All checks passed.\n")
