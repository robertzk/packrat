silent <- function(expr) {
  suppressWarnings(suppressMessages(
    capture.output(result <- eval(expr, envir = parent.frame()))
  ))
  result
}

forceUnload <- function(pkg) {

  # force detach from search path
  detach(pkg, character.only = TRUE, unload = TRUE, force = TRUE)

  # unload DLL if there is one
  pkgName <- gsub("package:", "", pkg, fixed = TRUE)
  pkgDLL <- getLoadedDLLs()[[pkgName]]
  if (!is.null(pkgDLL)) {
    suppressWarnings(
      library.dynam.unload(pkgName, system.file(package=pkgName))
    )
  }
}

list_files <- function(path = ".", pattern = NULL, all.files = FALSE,
                       full.names = FALSE, recursive = FALSE, ignore.case = FALSE,
                       include.dirs = FALSE, no.. = TRUE) {

  files <- list.files(path = path, pattern = pattern, all.files = all.files,
                      full.names = full.names, recursive = recursive,
                      ignore.case = ignore.case, include.dirs = include.dirs, no.. = no..)

  dirs <- list.dirs(path = path, full.names = full.names, recursive = recursive)
  setdiff(files, dirs)

}

# wrapper around read.dcf to workaround LC_CTYPE bug
# (see: http://r.789695.n4.nabble.com/Bug-in-read-dcf-all-TRUE-td4690578.html)
readDcf <- function(...) {
  loc <- Sys.getlocale('LC_CTYPE')
  on.exit(Sys.setlocale('LC_CTYPE', loc))
  read.dcf(...)
}

is_dir <- function(file) {
  isTRUE(file.info(file)$isdir) ## isTRUE guards against NA (ie, missing file)
}

# Copy a directory at file location 'from' to location 'to' -- this is kludgey,
# but file.copy does not handle copying of directories cleanly
dir_copy <- function(from, to, overwrite = FALSE, all.files = TRUE,
                     pattern = NULL, ignore.case = TRUE) {

  # Make sure we're doing sane things
  if (!is_dir(from)) stop("'", from, "' is not a directory.")

  if (file.exists(to)) {
    if (overwrite) {
      unlink(to, recursive = TRUE)
    } else {
      stop(paste( sep = "",
                  if (is_dir(to)) "Directory" else "File",
                  " already exists at path '", to, "'."
      ))
    }
  }

  success <- dir.create(to)
  if (!success) stop("Couldn't create directory '", to, "'.")

  # Get relative file paths
  files.relative <- list.files(from, all.files = all.files, full.names = FALSE,
                               pattern = pattern, recursive = TRUE, no.. = TRUE)

  # Get paths from and to
  files.from <- file.path(from, files.relative)
  files.to <- file.path(to, files.relative)

  # Create the directory structure
  dirnames <- unique(dirname(files.to))
  sapply(dirnames, function(x) dir.create(x, recursive = TRUE, showWarnings = FALSE))

  # Copy the files
  res <- file.copy(files.from, files.to)
  if (!all(res)) {
    # The copy failed; we should clean up after ourselves and return an error
    unlink(to, recursive = TRUE)
    stop("Could not copy all files from directory '", from, "' to directory '", to, "'.")
  }
  setNames(res, files.relative)

}

wrap <- function(x, width = 78, ...) {
  paste(strwrap(x = paste(x, collapse = " "), width = width, ...), collapse = "\n")
}

pkgDescriptionDependencies <- function(file) {

  fields <- c("Depends", "Imports", "Suggests", "LinkingTo")

  if (!file.exists(file)) stop("no file '", file, "'")
  DESCRIPTION <- readDcf("DESCRIPTION")
  requirements <- DESCRIPTION[1, fields[fields %in% colnames(DESCRIPTION)]]

  ## Remove whitespace
  requirements <- gsub("[[:space:]]*", "", requirements)

  ## Parse packages + their version
  parsed <- vector("list", length(requirements))
  for (i in seq_along(requirements)) {
    x <- requirements[[i]]
    splat <- unlist(strsplit(x, ",", fixed = TRUE))
    res <- lapply(splat, function(y) {
      if (grepl("(", y, fixed = TRUE)) {
        list(
          Package = gsub("\\(.*", "", y),
          Version = gsub(".*\\((.*?)\\)", "\\1", y, perl = TRUE),
          Field = names(requirements)[i]
        )
      } else {
        list(
          Package = y,
          Version = NA,
          Field = names(requirements)[i]
        )
      }
    })
    parsed[[i]] <- list(
      Package = sapply(res, "[[", "Package"),
      Version = sapply(res, "[[", "Version"),
      Field = sapply(res, "[[", "Field")
    )
  }

  result <- do.call(rbind, lapply(parsed, function(x) {
    as.data.frame(x, stringsAsFactors = FALSE)
  }))

  ## Don't include 'base' packages
  ip <- installed.packages()
  basePkgs <- ip[ Vectorize(isTRUE)(ip[, "Priority"] == "base"), "Package" ]
  result <- result[ !(result$Package %in% basePkgs), ]

  ## Don't include R
  result <- result[ !result$Package == "R", ]

  result

}

# does str1 start with str2?
startswith <- function(str1, str2) {
  if (!length(str2) == 1) stop("expecting a length 1 string for 'str2'")
  sapply(str1, function(x) {
    identical(
      substr(x, 1, min(nchar(x), nchar(str2))),
      str2
    )
  })
}

# does str1 end with str2?
endswith <- function(str1, str2) {
  if (!length(str2) == 1) stop ("expecting a length 1 string for 'str2'")
  n2 <- nchar(str2)
  sapply(str1, function(x) {
    nx <- nchar(x)
    identical(
      substr(x, nx - n2 + 1, nx),
      str2
    )
  })
}

stopIfNotPackified <- function(project) {
  if (!checkPackified(project, quiet = TRUE)) {
    if (identical(project, getwd())) {
      stop("This project has not yet been packified.\nRun 'packrat::bootstrap() to bootstrap packrat.",
           call. = FALSE)
    } else {
      stop("The project at '", project, "' has not yet been packified.\nRun 'packrat::bootstrap('", project, "') to bootstrap packrat.",
           call. = FALSE)
    }
  }
}

## Expected to be used with .Rbuildignore, .Rinstignore
updateIgnoreFile <- function(project = NULL, file, add = NULL, remove = NULL) {

  project <- getProjectDir(project)

  ## If the file doesn't exist, create and fill it
  path <- file.path(project, file)
  if (!file.exists(path)) {
    cat(add, file = file, sep = "\n")
    return(invisible())
  }

  ## If it already exists, add and remove as necessary
  content <- readLines(path)
  content <- union(content, add)
  content <- setdiff(content, remove)
  cat(content, file = path, sep = "\n")
  return(invisible())

}

updateRBuildIgnore <- function(project = NULL, options) {
  updateIgnoreFile(project = project, file = ".Rbuildignore", add = "^packrat/")
}

updateGitIgnore <- function(project = NULL, options) {
  git.options <- options[grepl("^vcs", names(options))]

  names(git.options) <- swap(
    names(git.options),
    c(
      "vcs.ignore.lib" = paste0(relLibraryRootDir(), "/"),
      "vcs.ignore.src" = paste0(relSrcDir(), "/")
    )
  )
  add <- names(git.options)[sapply(git.options, isTRUE)]
  remove <- names(git.options)[sapply(git.options, isFALSE)]
  add <- unique(c(add,
                  paste(relNewLibraryDir(), "/", sep = ""),
                  paste(relOldLibraryDir(), "/", sep = "")
  ))

  if (is.mac()) {
    add <- c(add, "packrat/lib-R/")
  }

  ## Add a comment so we can distinguish between packrat-added settings and user-added settings
  msg <- "# Automatically added by Packrat"
  add <- paste(add, msg)
  remove <- paste(remove, msg)

  updateIgnoreFile(project = project, file = ".gitignore", add = add, remove = remove)
}

isGitProject <- function(project) {
  .git <- file.path(project, ".git")
  file.exists(.git) && is_dir(.git)
}

isSvnProject <- function(project) {
  .svn <- file.path(project, ".svn")
  file.exists(.svn) && is_dir(.svn)
}

getSvnIgnore <- function(svn, dir) {
  owd <- getwd()
  on.exit(setwd(owd))
  setwd(dir)
  result <- system(paste(svn, "propget", "svn:ignore"), intern = TRUE)
  result[result != ""]
}

setSvnIgnore <- function(svn, dir, ignores) {
  owd <- getwd()
  on.exit(setwd(owd))
  setwd(dir)
  ignores <- paste(ignores, collapse = "\n")
  system(paste(svn, "propset", "svn:ignore", shQuote(ignores), "."), intern = TRUE)
}

updateSvnIgnore <- function(project, options) {

  svn.options <- options[grepl("^vcs", names(options))]
  names(svn.options) <- swap(
    names(svn.options),
    c(
      "vcs.ignore.lib" = relLibraryRootDir(),
      "vcs.ignore.src" = relSrcDir()
    )
  )
  add <- names(svn.options)[sapply(svn.options, isTRUE)]
  remove <- names(svn.options)[sapply(svn.options, isFALSE)]

  ## We need to explicitly exclude library.new, library.old
  add <- unique(c(add,
                  relNewLibraryDir(),
                  relOldLibraryDir()
  ))

  if (is.mac()) {
    add <- c(add, "packrat/lib-R")
  }

  svn <- Sys.which("svn")
  if (svn == "") {
    stop("Could not locate an 'svn' executable on your PATH")
  }
  ignores <- getSvnIgnore(svn, project)
  ignores <- union(ignores, add)
  ignores <- setdiff(ignores, remove)

  setSvnIgnore(svn, project, ignores)

}

## Wrappers over setLibPaths that do some better error reporting
setLibPaths <- function(paths) {
  for (path in paths) {
    if (!file.exists(path)) {
      stop("No directory exists at path '", path, "'")
    }
  }
  .libPaths(paths)
}

## We only want to grab user libraries here -- system libraries are automatically
## added in by R
getLibPaths <- function(paths) {
  setdiff(.libPaths(), c(.Library, .Library.site))
}

getInstalledPkgInfo <- function(packages, installed.packages, ...) {
  ip <- installed.packages
  missingFromLib <- packages[!(packages %in% rownames(ip))]
  if (length(missingFromLib)) {
    warning("The following packages are not installed in the current library:\n- ",
            paste(missingFromLib, sep = ", "))
  }
  packages <- setdiff(packages, missingFromLib)
  getPkgInfo(packages, ip)
}

getPkgInfo <- function(packages, installed.packages) {

  records <- installed.packages[packages, , drop = FALSE]

  ## Convert from matrix to list
  records <- apply(records, 1, as.list)

  ## Parse the package dependency fields -- we split up the depends, imports, etc.
  for (i in seq_along(records)) {
    for (field in c("Depends", "Imports", "LinkingTo", "Suggests", "Enhances")) {
      item <- records[[i]][[field]]
      if (is.na(item)) next
      item <- gsub("[[:space:]]*(.*?)[[:space:]]*", "\\1", item, perl = TRUE)
      item <- unlist(strsplit(item, ",[[:space:]]*", perl = TRUE))

      ## Remove version info
      item <- gsub("\\(.*", "", item)
      records[[i]][[field]] <- item
    }
  }
  records
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

`%nin%` <- function(x, y) {
  !(x %in% y)
}

isFALSE <- function(x) identical(x, FALSE)

swap <- function(vec, from, to = NULL) {

  if (is.null(to)) {
    to <- unname(unlist(from))
    from <- names(from)
  }

  tmp <- to[match(vec, from)]
  tmp[is.na(tmp)] <- vec[is.na(tmp)]
  return(tmp)
}


attemptRestart <- function() {
  restart <- getOption("restart")
  if (!is.null(restart)) {
    restart()
    TRUE
  } else {
    FALSE
  }
}
