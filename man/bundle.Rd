% Generated by roxygen2 (4.0.1.99): do not edit by hand
\name{bundle}
\alias{bundle}
\title{Bundle a Packrat Project}
\usage{
bundle(project = NULL, file = NULL, include.src = TRUE,
  include.lib = FALSE, overwrite = FALSE, ...)
}
\arguments{
\item{project}{The project directory. Defaults to the currently activate
project. By default, the current project active under \code{packratMode}
is checked.}

\item{file}{The location to file the bundled file. By default, we write
to a file with name \code{<package>-<date>.zip}.}

\item{include.src}{Include the packrat sources?}

\item{include.lib}{Include the packrat private library?}

\item{overwrite}{Boolean; overwrite the file at \code{file} if it already exists?}

\item{...}{Optional arguments passed to \code{\link{tar}}.}
}
\description{
Bundle a packrat project, for easy sharing.
}

