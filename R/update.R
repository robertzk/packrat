updateInit <- function() {
  init.R <- readLines(file.path("inst", "init.R"))
  packrat.version <- read.dcf("DESCRIPTION")[1, "Version"]
  init.R[1] <- paste(sep = "",
                     "#### -- Packrat Autoloader (version ", packrat.version, ") -- ####")
  init.R[length(init.R)] <- "#### -- End Packrat Autoloader -- ####"

  ## Sync the packrat path, messages
  source("R/aaa-globals.R")

  ## Update library path
  libraryPathMarker <- "## -- packrat::libDir -- ##"
  filePathArgs <- c(
    shQuote(.packrat$packratFolderName),
    shQuote("lib"),
    "R.version$platform",
    "getRversion()"
  )
  filePathCmd <- paste(sep = "",
                       "file.path(", paste(filePathArgs, collapse = ", "), ")")
  libPathLine <- grep(paste(sep = "", libraryPathMarker, "$"),
                      init.R)
  libPathCmd <- paste(sep = "", "libDir <- ", filePathCmd)
  init.R[libPathLine + 1] <- paste("  ", libPathCmd, sep = "")

  ## Update bootstrap path
  bootstrapPathMarker <- "## -- packrat::bootstrapPath -- ##"
  bootstrapPath <- file.path(.packrat$packratFolderName, "bootstrap.R")
  fileCheckLine <- grep( paste(sep = "", bootstrapPathMarker, "$"),
                         init.R)
  bootstrapPathCmd <- paste("    bootstrapPath <-", shQuote(bootstrapPath))
  init.R[fileCheckLine + 1] <- bootstrapPathCmd

  ## Update bootstrap message
  bootstrapMsgMarker <- "## -- packrat::bootstrapMessage -- ##"
  msgLine <- grep(paste(sep = "", bootstrapMsgMarker, "$"),
                  init.R)
  init.R[msgLine + 1] <- paste(sep = "",
                               "      message('Run \\\'source(\"",
                               bootstrapPath,
                               "\")\\\' to bootstrap a packrat installation.\')")

  cat(init.R, file=file.path("inst", "init.R"), sep = "\n")
}


updateBootstrap <- function() {
  bootstrap.R <- readLines(file.path("inst", "bootstrap.R"))
  packrat.version <- read.dcf("DESCRIPTION")[1, "Version"]

  ## Sync the packrat path, messages
  source("R/aaa-globals.R")

  installAgentLine <- grep("## -- InstallAgent -- ##", bootstrap.R)
  bootstrap.R[installAgentLine + 1] <- paste("installAgent <-", shQuote(paste("InstallAgent:", "packrat", packrat.version)))

  installSourceLine <- grep("## -- InstallSource -- ##", bootstrap.R)
  bootstrap.R[installSourceLine + 1] <- paste("installSource <-", shQuote(paste("InstallSource:", "source")))

  cat(bootstrap.R, file = file.path("inst", "bootstrap.R"), sep = "\n")
}