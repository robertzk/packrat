#' Packrat: Reproducible dependency management
#'
#' Packrat is a tool for managing the \R packages your project depends on in
#' an isolated, portable, and reproducible way.
#'
#' Use packrat to make your \R projects more:
#'
#' \itemize{
#' \item \strong{Isolated}: Installing a new or updated package for one project
#' won't break your other projects, and vice versa. That's because packrat gives
#' each project its own private package library.
#' \item \strong{Portable}: Easily transport your projects from one computer to
#' another, even across different platforms. Packrat makes it easy to install the
#' packages your project depends on.
#' \item \strong{Reproducible}: Packrat records the exact package versions you
#' depend on, and ensures those exact versions are the ones that get installed
#' wherever you go.}
#'
#' Use \code{\link{bootstrap}} to create a new packrat project,
#' \code{\link{snapshot}} to record changes to your project's library, and
#' \code{\link{restore}} to recreate your library the way it was the last time you
#' (or anyone!) took a snapshot.
#'
#' Using these simple functions and sharing packrat's files lets you collaborate
#' in a shared, consistent environment with others as your project grows and
#' changes, and provides an easy way to share your results when you're done.
#'
#' @section Anatomy of a packrat project:
#'
#' A packrat project contains a few extra files and directories. The
#' \code{\link{bootstrap}} function creates these files for you, if they don't
#' already exist.
#'
#' \describe{
#'   \item{\code{packrat/lib/}}{Private package library for this project.}
#'   \item{\code{packrat/src/}}{Source packages of all the dependencies that
#'packrat has been made aware of.}
#'
#'   \item{\code{packrat/packrat.lock}}{Lists the precise package versions that were used
#' to satisfy dependencies, including dependencies of dependencies. (This file
#' should never be edited by hand!)}
#'
#'   \item{\code{.Rprofile}}{Directs \R to use the private package
#' library (when it is started from the project directory).}
#' }
#'
#' @section Using packrat with version control:
#'
#' Packrat is designed to work hand in hand with Git, Subversion, or any other
#' version control system. Be sure to check in the \code{.Rprofile},
#' \code{packrat.lock} files, and everything under
#' \code{packrat/src/}. You can tell your VCS to ignore \code{packrat/lib/} (or
#' feel free to check it in if you don't mind taking up some extra space in your
#' repository).
#'
#' @examples
#' \dontrun{
#' # Create a new packrat project from an existing directory of \R code
#' bootstrap()
#'
#' # Install a package and take a snapshot of the new state of the library
#' install.packages("TTR")
#' snapshot()
#'
#' # Accidentally remove a package and restore to add it back
#' remove.packages("TTR")
#' restore()
#' }
#'
#' @docType package
#' @name packrat
#' @author RStudio, Inc.
NULL

#' Initialize Packrat on a new or existing \R project
#'
#' Given a project directory, makes a new packrat project in the directory.
#'
#' \code{bootstrap} works as follows:
#'
#' \enumerate{
#'
#' \item Application dependencies are computed by examining the \R code
#' throughout the project for \code{library} and \code{require} calls.
#'
#' \item A snapshot is taken of the version of each package currently used by
#' the project as described in \code{\link{snapshot}}, and each package's
#' sources are downloaded.
#'
#' \item A private library is created in the directory.
#'
#' \item The snapshot is applied to the directory as described in
#' \code{\link{restore}}. } When \code{bootstrap} is finished, all the packages
#' on which the project depends are installed in a new, private library located
#' inside the project directory.
#'
#' \strong{You must restart your \R session in the given project directory after
#' running \code{bootstrap} in order for the changes to take effect!}
#'
#' When \R is started in the directory, it will use the new, private library.
#' Calls to \code{\link{require}} and \code{\link{library}} will load packages
#' from the private library (except for 'base' or 'recommended' \R packages,
#' which are found in the system library), and functions such as \code{\link{install.packages}}
#' will modify that private library. You can sync this private library with
#' packrat using \code{\link{snapshot}} and \code{\link{restore}}.
#'
#' @param project The directory that contains the \R project.
#' @param source.packages List of paths to unpacked \R package source
#'   directories.  Use this argument only if your project depends on packages
#'   that are not available on CRAN or GitHub.
#' @param enter Boolean, enter packrat mode for this project after finishing a bootstrap?
#'
#' @seealso \link{packrat} for a description of the files created by
#'   \code{bootstrap}.
#'
#' @export
bootstrap <- function(project = '.', source.packages = character(), enter = TRUE) {

  ## Force packrat mode off
  suppressMessages(packrat_mode(on = FALSE))

  project <- normalizePath(project, winslash='/', mustWork=TRUE)
  if (!checkPackified(project = project, quiet = TRUE)) {
    packify(project = project, quiet = TRUE)
  }

  descriptionFile <- file.path(project, 'DESCRIPTION')

  if (file.exists(descriptionFile)) {
    description <- as.data.frame(readDcf(descriptionFile))
    package <- description$Package
  }

  # Take a snapshot
  source.packages <- getSourcePackageInfo(source.packages)
  snapshotImpl(project, available.packages(contrib.url(activeRepos(project))),
               source.packages=source.packages, lib.loc = NULL, ignore.stale=TRUE)

  # Use the lockfile to copy sources and install packages to the library
  restore(project, overwrite.dirty = TRUE, restart = FALSE)

  # Copy bootstrap.R so a user can 'start from zero' with a project
  file.copy(
    instInitFilePath(),
    file.path(project, .packrat$packratFolderName, "init.R")
  )

  ## Make sure the .Rprofile, .gitignore, etc. are up to date
  augmentRprofile(project)
  options <- initOptions(project) ## writes out packrat.opts and returns generated list
  updateSettings(project, options)

  ## Symlink system libraries on mac
  if (is.mac()) {
    symlinkSystemPackages(project = project)
  }

  message("Bootstrap complete!")

  if (enter) {

    setwd(project)

    # Restart R if the environment is capable of it (otherwise enter packrat mode)
    if (!attemptRestart())
      packrat_mode(on = TRUE, project = project, clean.search.path = TRUE)
  }

  invisible()
}

#' Apply the most recent snapshot to the library
#'
#' Applies the most recent snapshot to the project's private library.
#'
#' \code{restore} works by adding, removing, and changing packages so that the
#' set of installed packages and their versions matches the snapshot exactly.
#'
#' There are three common use cases for \code{restore}:
#' \itemize{
#'   \item \strong{Hydrate}: Use \code{restore} after copying a project to a new
#' machine to populate the library on that machine.
#'
#'   \item \strong{Sync}: Use \code{restore} to apply library changes made by a
#' collaborator to your own library. (In general, you want to run \code{restore}
#' whenever you pick up a change to \code{packrat.lock})
#'
#'   \item \strong{Rollback}: Use \code{restore} to undo accidental changes made
#' to the library since the last snapshot.
#' }
#'
#' \code{restore} cannot make changes to packages that are currently loaded. If
#' changes are necessary to currently loaded packages, you will need to restart
#' \R to apply the changes (\code{restore} will let you know when this is
#' necessary). It is recommended that you do this as soon as possible, because
#' any library changes made between running \code{restore} and restarting \R will
#' be lost.
#'
#' @note
#' \code{restore} can be destructive; it will remove packages that were not in
#' the snapshot, and it will replace newer packages with older versions if
#' that's what the snapshot indicates. \code{restore} will warn you before
#' attempting to remove or downgrade a package (if \code{prompt} is
#' \code{TRUE}), but will always perform upgrades and new installations without
#' prompting.
#'
#' \code{restore} works only on the private package library created by packrat;
#' if you have other libraries on your path, they will be unaffected.
#'
#' The \code{restart} parmaeter will only result in a restart of R when the
#' R environment packrat is running within makes available a restart function
#' via \code{getOption("restart")}.
#'
#' @param project The project directory. When in packrat mode, if this is \code{NULL},
#' then the directory associated with the current packrat project is used. Otherwise,
#' the project directory specified is used.
#' @param overwrite.dirty A dirty package is one that has been changed since the
#' last snapshot or restore. Packrat will leave these alone by default. If you
#' want to guarantee that \code{restore} will put you in the exact state
#' represented by the snapshot being applied, use \code{overwrite.dirty = TRUE}.
#' @param prompt \code{TRUE} to prompt before performing potentially destructive
#' changes (package removals or downgrades); \code{FALSE} to perform these
#' operations without confirmation.
#' @param dry.run If \code{TRUE}, compute the changes to your packrat state that
#'   would be made if a restore was performed, without actually executing them.
#' @param restart If \code{TRUE}, restart the R session after restoring.
#'
#' @seealso
#' \code{\link{snapshot}}, the command that creates the snapshots applied with
#' \code{restore}.
#'
#' \code{\link{status}} to view the differences between the most recent snapshot
#' and the library.
#'
#' @export
restore <- function(project = NULL,
                    overwrite.dirty = FALSE,
                    prompt = interactive(),
                    dry.run = FALSE,
                    restart = !dry.run) {

  project <- getProjectDir(project)
  stopIfNotPackified(project)

  callHook("restore", TRUE)
  on.exit(callHook("restore", FALSE), add = TRUE)

  # RTools cp.exe (invoked during installation) can warn on Windows since we
  # use paths of the format c:/foo/bar and it prefers /cygwin/c/foo/bar.
  # Unfortunately, R's implementation of tar treats this warning output as
  # though it were part of the list of files in the archive.
  cygwin <- Sys.getenv("CYGWIN", unset = NA)
  if (Sys.info()["sysname"] == "Windows" && length(grep("nodosfilewarning", cygwin)) == 0) {
    Sys.setenv("CYGWIN" = paste(cygwin, "nodosfilewarning"))
    on.exit(Sys.setenv("CYGWIN" = cygwin), add = TRUE)
  }

  packages <- lockInfo(project)
  r_version <- lockInfo(project, 'r_version')
  if (!identical(as.character(getRversion()), r_version)) {
    warning('The most recent snapshot was generated using R version ',
            r_version)
  }

  # Make sure the library directory exists
  libDir <- libDir(project)
  if (!file.exists(libDir)) {
    dir.create(libDir, recursive=TRUE)
  }

  # See if any of the packages that are currently in the library are dirty.
  # Dirty packages that are represented in the snapshot will be either ignored
  # (with a message) or overwritten, depending on the value of the
  # overwrite.dirty flag. Dirty packages that are not represented in the snapshot
  # (like git untracked) will be silently ignored in all cases.

  libPkgNames <- rownames(installed.packages(libDir, noCache=TRUE))
  dirty <- !installedByPackrat(libPkgNames, libDir, TRUE)
  dirtyPackageNames <- libPkgNames[dirty]

  if (!isTRUE(overwrite.dirty)) {
    prettyPrint(
      packages[pkgNames(packages) %in% dirtyPackageNames],
      'The following packages were not installed by packrat and will be ignored:',
      'If you would like to overwrite them, call restore again with\noverwrite.dirty = TRUE.'
    )
    # Keep all dirty packages
    pkgsToIgnore <- dirtyPackageNames
  } else {
    # Even if overwrite.dirty is TRUE, we still want to keep packages that are
    # dirty and NOT represented in the list of packages to install (this is akin
    # to "untracked" files in git).
    pkgsToIgnore <- dirtyPackageNames[!dirtyPackageNames %in% pkgNames(packages)]
  }

  # Install each package from CRAN or github, from binaries when available and
  # then from sources.
  repos <- lockInfo(project, 'repos')
  repos <- strsplit(repos, "\\s*,\\s*")[[1]]
  restoreImpl(project, repos, packages, libDir,
              pkgsToIgnore = pkgsToIgnore, prompt = prompt,
              dry.run = dry.run)
}

#' Remove unused packages
#'
#' Remove unused packages from the given library.
#'
#' Detects and removes orphaned packages. Orphaned packages are those that meet
#' the following criteria:
#' \itemize{
#'   \item Installed in the library
#'   \item Not directly used by any \R code in the project
#'   \item Not a dependency of any non-orphaned package
#' }
#' If \code{clean} wants to remove a package but your project actually needs the
#' package, add a statement such as \code{\link{require}(package-name)} to any .R
#' file in your project's directory.
#'
#' @param project The project directory. Defaults to current working
#' directory.
#' @param lib.loc The library to clean. Defaults to the private package library
#' associated with the project directory.
#' @param prompt \code{TRUE} to prompt before removing packages, \code{FALSE} to
#' remove packages immediately.
#'
#' @export
clean <- function(project = NULL, lib.loc = libDir(project),
                  prompt = interactive()) {

  project <- getProjectDir(project)
  stopIfNotPackified(project)

  callHook("clean", TRUE)
  on.exit(callHook("clean", FALSE), add = TRUE)

  rootDeps <- appDependencies(project)
  missingPackageNames <- character(0)
  packagesInUse <- getPackageRecords(
    rootDeps, available=NULL, source.packages=NULL, recursive=TRUE,
    lib.loc=c(lib.loc, getLibPaths()),
    missing.package = function(pkgName, lib.loc) {
      missingPackageNames <<- c(missingPackageNames, pkgName)
      return(NULL)
    }
  )
  missingPackageNames <- sort(unique(missingPackageNames))

  prettyPrintNames(
    missingPackageNames,
    c("Can't detect orphaned packages because these package(s) are not installed:")
  )
  if (length(missingPackageNames) > 0) {
    return(invisible())
  }

  installedPkgNames <- row.names(installed.packages(
    lib.loc=lib.loc, priority=c('NA', 'recommended'), noCache=TRUE))

  orphans <- setdiff(installedPkgNames,
                     pkgNames(flattenPackageRecords(packagesInUse)))

  ## Exclude 'manipulate', 'rstudio'
  orphans <- setdiff(orphans, c("manipulate", "rstudio"))

  if (length(orphans) > 0) {
    orphanRecs <- getPackageRecords(orphans, available=NULL,
                                    source.packages=NULL,
                                    recursive=FALSE,
                                    lib.loc=lib.loc)

    prettyPrint(orphanRecs,
                'The following packages will be removed:')

    if (prompt) {
      answer <- readline('Do you want to continue? [Y/n] ')
      answer <- gsub('^\\s*(.*?)\\s*$', '\\1', answer)
      if (nzchar(answer) && tolower(answer) != 'y') {
        return(invisible())
      }
    }

    removePkgs(project, orphans, lib.loc)
    message("Packages '", paste(orphans, collapse = ", "), "' have been removed from the private library.")
    return(invisible(orphans))
  } else {
    message("Already up to date.")
  }
}

#' Automatically Enter Packrat Mode on Startup
#'
#' Install/augment the \code{.Rprofile} in a project, so that all \R sessions
#' started in this directory enter \code{packrat mode}, and use the local
#' project library.
#'
#' It is not normally necessary to call \code{packify} directly; these files are
#' normally installed by \code{\link{bootstrap}}. \code{packify} can be used to
#' restore the files if they are missing (for instance, if they were not added to
#' source control, or were accidentally removed).
#'
#' You'll need to restart \R in the specified directory after running
#' \code{packify} in order to start using the private package library.
#'
#' @param project The directory in which to install the \code{.Rprofile} file.
#' @param quiet Be chatty?
#' @export
packify <- function(project = NULL, quiet = FALSE) {

  project <- getProjectDir(project)
  packratDir <- getPackratDir(project)

  if (!file.exists(packratDir)) {
    dir.create(packratDir)
  }

  libraryRootDir <- libraryRootDir(project)
  if (!file.exists(libraryRootDir)) {
    dir.create(libraryRootDir)
  }

  srcDir <- srcDir(project)
  if (!file.exists(srcDir)) {
    dir.create(srcDir)
  }

  .Rprofile <- file.path(project, ".Rprofile")
  init.R <- instInitRprofileFilePath()

  if (!file.exists(.Rprofile)) {
    file.copy(init.R, .Rprofile)
  } else {
    # Check and see if we've already packified
    txt <- readLines(.Rprofile)
    if (any(grepl("#### -- Packrat Autoloader", txt, fixed = TRUE))) {
      message("This project has already been packified!")
      return(invisible())
    }
    cat(txt, file = .Rprofile, append = TRUE)
  }

  if (!quiet) {
    msg <- "Packrat startup directives installed."

    if (identical(project, getwd())) {
      msg <- paste(msg, "Please call \"packrat::packrat_on()\" to initialize packrat.")
    } else {
      msg <- paste(msg, "Please call \"packrat::packrat_on(project = '", project, "')\"",
                   "to initialize packrat.")
    }

    message(msg)
  }

  invisible()
}

lockInfo <- function(project, property='packages', fatal=TRUE) {

  project <- getProjectDir(project)

  # Get and parse the lockfile
  lockFilePath <- lockFilePath(project)
  if (!file.exists(lockFilePath)) {
    if (fatal) {
      stop(paste(lockFilePath, " is missing. Run packrat::bootstrap('",
                 project, "') to generate it.", sep = ""))
    } else {
      return(list())
    }
  }
  readLockFile(lockFilePath)[[property]]
}

