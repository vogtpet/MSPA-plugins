## ---------------------------------------------------------------------------
##
## RMSPA - Morphological Spatial Pattern Analysis for R
##
## A Shiny wrapper around the MSPA command line tool. See README.md for
## installation instructions and CHANGELOG.md for the version history.
##
## The plugin version is stored in VERSION, the wrapped MSPA version in
## MSPA_VERSION. Both are shown in the interface.
##
## ---------------------------------------------------------------------------

## Locate the application folder. This works for RStudio's "Run App", for
## shiny::runApp("path/to/RMSPA") and for Rscript path/to/app.R.
app_dir <- local({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
  if (length(file_arg) == 1L && nzchar(file_arg)) {
    return(normalizePath(dirname(file_arg), mustWork = FALSE))
  }
  if (file.exists(file.path(getwd(), "app.R"))) {
    return(normalizePath(getwd(), mustWork = FALSE))
  }
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    path <- tryCatch(rstudioapi::getSourceEditorContext()$path,
                     error = function(e) "")
    if (nzchar(path)) return(normalizePath(dirname(path), mustWork = FALSE))
  }
  normalizePath(getwd(), mustWork = FALSE)
})

source(file.path(app_dir, "R", "platform.R"), local = FALSE)
source(file.path(app_dir, "R", "process.R"), local = FALSE)
source(file.path(app_dir, "R", "update.R"), local = FALSE)

plugin_version <- read_first_line(file.path(app_dir, "VERSION"), "0.0.0-dev")
mspa_version <- read_first_line(file.path(app_dir, "MSPA_VERSION"), "")

## ---- required R packages ---------------------------------------------------
required_packages <- c("shiny", "shinyFiles", "shinyjs", "terra", "later")
missing_packages <- required_packages[!vapply(required_packages,
                                              requireNamespace,
                                              logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  message("RMSPA: installing required R packages: ",
          paste(missing_packages, collapse = ", "))
  repos <- getOption("repos")
  if (is.null(repos) || length(repos) == 0L ||
      identical(unname(repos["CRAN"]), "@CRAN@")) {
    repos <- c(CRAN = "https://cloud.r-project.org")
  }
  old_timeout <- getOption("timeout")
  options(timeout = max(600, old_timeout))
  utils::install.packages(missing_packages, repos = repos)
  options(timeout = old_timeout)

  missing_packages <- required_packages[!vapply(required_packages,
                                                requireNamespace,
                                                logical(1), quietly = TRUE)]
  if (length(missing_packages) > 0L) {
    stop("RMSPA: could not install the required R packages: ",
         paste(missing_packages, collapse = ", "),
         "\nPlease install them manually with install.packages() and start RMSPA again.",
         call. = FALSE)
  }
}

library(shiny)

options(shiny.maxRequestSize = 1e9)

## Check the bundled MSPA binary once per session.
runtime <- mspa_runtime(app_dir, expected_version = mspa_version)

## ---- interface -------------------------------------------------------------
panel_style <- paste("border-style: solid;",
                     "border-width: 1px;",
                     "border-radius: 4px;",
                     "border-color: #112446;",
                     "padding-top: 7px;",
                     "padding-bottom: 11px;")

ui <- fluidPage(
  shinyjs::useShinyjs(),

  tags$head(tags$style(HTML(
    ".selectize-input, .selectize-dropdown, .control-label { font-size: 12px; }
     .form-group, .progress { margin-bottom: 10px; }
     .rmspa-info { font-size: 12px; line-height: 1.5; }
     .rmspa-info code { font-size: 11px; }
     .rmspa-version { font-size: 70%; color: #666; font-weight: normal; margin-left: 8px; }"
  ))),

  titlePanel(
    windowTitle = sprintf("RMSPA - %s", plugin_version),
    title = div(sprintf("RMSPA - %s", plugin_version),
                tags$span(sprintf("MSPA %s", mspa_version), class = "rmspa-version"))
  ),

  uiOutput("runtimeInfo"),

  wellPanel(
    style = panel_style,
    h5(strong("Step 1: Input image")),
    fileInput("btnSelectFile", NULL,
              accept = c("image/tiff", ".tif", ".tiff"),
              buttonLabel = list(icon("folder"), " Browse...")),
    radioButtons("encoding", "Input encoding",
                 choices = c(
                   "GTB: 1 = background, 2 = foreground" = "gtb",
                   "Binary mask: 0 = background, 1 = foreground" = "mask"
                 ),
                 selected = "gtb"),
    helpText("MSPA expects a single-band 8-bit GeoTIFF. Missing data must be 0."),
    uiOutput("inputInfo")
  ),

  wellPanel(
    style = panel_style,
    h5(strong("Step 2: MSPA parameters")),
    fluidRow(
      column(3, tags$div(title = "Foreground connectivity",
                         selectInput("fgconn", "FGconn", choices = c("8", "4")))),
      column(3, tags$div(title = "Effective edge width",
                         selectInput("edgewidth", "EdgeWidth",
                                     choices = c("1", "2", "3", "4", "5")))),
      column(3, tags$div(title = "Transition flag",
                         selectInput("transition", "Transition", choices = c("1", "0")))),
      column(3, tags$div(title = "Internal flag",
                         selectInput("intext", "Internal", choices = c("1", "0"))))
    ),
    checkboxInput("lowmem", "Low memory mode (-disk)", value = FALSE),
    helpText(sprintf(paste0("Low memory mode is switched on automatically for ",
                            "images larger than %.0f million pixels."),
                     MSPA_DISK_PIXELS / 1e6))
  ),

  wellPanel(
    style = panel_style,
    h5(strong("Step 3: Process the image")),
    p(style = "margin: 0 0 5px;", align = "center",
      "Select the folder where the result is saved"),
    p(align = "center",
      shinyFiles::shinyDirButton("selectFolder", " Select a folder",
                                 "Select the folder where the result is saved",
                                 icon = icon("folder-open"),
                                 style = "width:70%;")),
    div(style = "width:70%; margin:auto;",
        verbatimTextOutput("selectFolder", placeholder = TRUE)),
    p(align = "center",
      actionButton("btnStart", "Start",
                   style = paste("width:70%; background-color:#004494;",
                                 "border-color:#112446; color:white;")))
  ),

  wellPanel(
    style = panel_style,
    h5(strong("Help")),
    fluidRow(
      column(6, a("Plugin guide", class = "btn btn-info",
                  style = "width:100%; border-color:#112446;",
                  href = "https://github.com/vogtpet/MSPA-plugins/blob/main/r/README.md",
                  target = "_blank")),
      column(6, a("MSPA guide", class = "btn btn-info",
                  style = "width:100%; border-color:#112446;",
                  href = "MSPA_Guide.pdf", target = "_blank"))
    ),
    p(style = "margin-top:10px; margin-bottom:0;",
      actionLink("checkUpdate", "Check for updates"),
      tags$span(class = "rmspa-version",
                sprintf("installed: %s", plugin_version)))
  ),

  wellPanel(
    style = panel_style,
    "Extended functionality is available in the free software ",
    actionLink("openGtb", "GuidosToolbox"), "."
  )
)

## ---- server ----------------------------------------------------------------
server <- function(input, output, session) {

  state <- reactiveValues(info = NULL, last = NULL, update = NULL, new_app = NULL)

  volumes <- c(Home = path.expand("~"), shinyFiles::getVolumes()())

  shinyFiles::shinyDirChoose(input, "selectFolder", roots = volumes,
                             session = session)

  output$selectFolder <- renderText({
    if (is.null(input$selectFolder) || is.integer(input$selectFolder)) {
      "No folder selected"
    } else {
      shinyFiles::parseDirPath(volumes, input$selectFolder)
    }
  })

  output$runtimeInfo <- renderUI({
    if (isTRUE(runtime$ok)) return(NULL)
    div(class = "alert alert-warning", style = "white-space:pre-wrap;",
        strong("MSPA is not available on this system."), "\n\n", runtime$detail)
  })

  ## ---- input validation ----------------------------------------------------
  inspect_input <- function() {
    file <- input$btnSelectFile
    if (is.null(file)) {
      state$info <- NULL
      return()
    }
    state$info <- tryCatch(
      mspa_inspect(file$datapath, encoding = input$encoding, name = file$name),
      error = function(e) list(ok = FALSE, message = conditionMessage(e))
    )
  }

  observeEvent(input$btnSelectFile, inspect_input(), ignoreNULL = FALSE)
  observeEvent(input$encoding, {
    if (!is.null(input$btnSelectFile)) inspect_input()
  })

  observe({
    if (isTRUE(runtime$ok) && isTRUE(state$info$ok)) {
      shinyjs::enable("btnStart")
    } else {
      shinyjs::disable("btnStart")
    }
  })

  output$inputInfo <- renderUI({
    info <- state$info
    if (is.null(info)) return(NULL)
    if (!isTRUE(info$ok)) {
      return(div(class = "alert alert-danger", style = "white-space:pre-wrap;",
                 info$message))
    }
    i <- info$info
    values <- i$values
    shown <- paste(sprintf("%d (%s)", values$value,
                           format(values$count, big.mark = ",")),
                   collapse = ", ")
    div(class = "rmspa-info",
        tags$div(sprintf("Size: %s x %s pixels (%.1f million)",
                         format(i$rows, big.mark = ","),
                         format(i$cols, big.mark = ","),
                         i$ncell / 1e6)),
        tags$div(sprintf("Data type: %s", i$datatype)),
        tags$div(sprintf("Projection: %s", i$crs)),
        tags$div(sprintf("Pixel values: %s", shown)),
        tags$div(sprintf("Foreground pixels: %s",
                         format(i$foreground, big.mark = ","))),
        if (i$disk) tags$div(em("The image is large; low memory mode will be used."))
    )
  })

  ## ---- processing ----------------------------------------------------------
  run_job <- function(file, outdir) {
    res <- tryCatch(
      mspa_process(
        input = file$datapath,
        outdir = outdir,
        graphfg = as.integer(input$fgconn),
        eew = as.integer(input$edgewidth),
        transition = as.integer(input$transition),
        internal = as.integer(input$intext),
        encoding = input$encoding,
        binary = runtime$binary,
        input_name = file$name,
        low_mem = isTRUE(input$lowmem)
      ),
      error = function(e) list(ok = FALSE, message = conditionMessage(e))
    )

    removeModal()

    if (!isTRUE(res$ok)) {
      shinyjs::enable("btnStart")
      showModal(modalDialog(
        title = "MSPA failed",
        div(style = "white-space:pre-wrap;", res$message),
        easyClose = TRUE,
        footer = modalButton("Close")
      ))
      return()
    }

    shinyjs::enable("btnStart")
    state$last <- res
    showModal(modalDialog(
      title = "MSPA finished",
      p("The classified image was saved to:"),
      tags$code(res$outfile),
      if (isTRUE(res$disk)) p(em("Low memory mode (-disk) was used.")),
      easyClose = TRUE,
      footer = tagList(
        actionButton("openOutFolder", "Open folder"),
        modalButton("Close")
      )
    ))
  }

  observeEvent(input$btnStart, {
    file <- input$btnSelectFile
    if (!isTRUE(runtime$ok) || is.null(file) || !isTRUE(state$info$ok)) return()

    selected <- input$selectFolder
    if (is.null(selected) || is.integer(selected)) {
      showModal(modalDialog("Please select a folder for the result.",
                            easyClose = TRUE, footer = modalButton("Close")))
      return()
    }
    outdir <- shinyFiles::parseDirPath(volumes, selected)
    if (!nzchar(outdir)) {
      showModal(modalDialog("Please select a folder for the result.",
                            easyClose = TRUE, footer = modalButton("Close")))
      return()
    }

    shinyjs::disable("btnStart")
    showModal(modalDialog(
      title = NULL,
      div(class = "text-center",
          h4("Processing image ..."),
          p("MSPA is running. This window closes when processing has finished.")),
      footer = NULL,
      easyClose = FALSE
    ))
    later::later(function() run_job(file, outdir), 0.25)
  })

  observeEvent(input$openOutFolder, {
    if (!is.null(state$last$outfile)) {
      utils::browseURL(dirname(state$last$outfile))
    }
  })

  ## ---- update check --------------------------------------------------------
  do_check <- function(manual = FALSE) {
    res <- tryCatch(
      check_for_update(plugin_version, refresh = manual),
      error = function(e) list(ok = FALSE, message = conditionMessage(e))
    )

    if (!isTRUE(res$ok)) {
      if (manual) {
        showModal(modalDialog("Update check", res$message,
                              easyClose = TRUE, footer = modalButton("Close")))
      }
      return()
    }

    if (!isTRUE(res$available)) {
      if (manual) {
        showModal(modalDialog("No update available", res$message,
                              easyClose = TRUE, footer = modalButton("Close")))
      }
      return()
    }

    state$update <- res
    showModal(modalDialog(
      title = "Update available",
      p(res$message),
      p("The new version can be downloaded and unpacked next to the current installation."),
      easyClose = TRUE,
      footer = tagList(
        tags$a(href = res$notes_url, target = "_blank",
               class = "btn btn-default", "Release notes"),
        actionButton("doUpdate", "Download and install"),
        modalButton("Later")
      )
    ))
  }

  session$onFlushed(function() {
    later::later(function() do_check(manual = FALSE), 1)
  }, once = TRUE)

  observeEvent(input$checkUpdate, do_check(manual = TRUE))

  observeEvent(input$doUpdate, {
    update <- state$update
    if (is.null(update)) return()

    showModal(modalDialog(
      title = NULL,
      div(class = "text-center",
          h4(sprintf("Downloading RMSPA %s ...", update$latest)),
          p("Please wait.")),
      footer = NULL,
      easyClose = FALSE
    ))

    later::later(function() {
      path <- tryCatch(install_update(update$latest, app_dir),
                       error = function(e) e)
      removeModal()

      if (inherits(path, "error")) {
        showModal(modalDialog(
          title = "Update failed",
          div(style = "white-space:pre-wrap;", conditionMessage(path)),
          easyClose = TRUE, footer = modalButton("Close")
        ))
        return()
      }

      state$new_app <- path
      showModal(modalDialog(
        title = "Update installed",
        p("The new version was unpacked to:"),
        tags$code(path),
        p(paste("Close RMSPA and start app.R from the new folder. The current",
                "installation is unchanged and can be deleted once the new",
                "version works.")),
        easyClose = FALSE,
        footer = tagList(
          actionButton("openNewFolder", "Open folder"),
          actionButton("quitApp", "Quit RMSPA"),
          modalButton("Close")
        )
      ))
    }, 0.25)
  })

  observeEvent(input$openNewFolder, {
    if (!is.null(state$new_app)) utils::browseURL(state$new_app)
  })

  observeEvent(input$quitApp, shiny::stopApp())

  observeEvent(input$openGtb, {
    utils::browseURL("https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb")
  })
}

shinyApp(ui = ui, server = server)
