% Generated by roxygen2 (4.0.1.99): do not edit by hand
\name{packrat-mode}
\alias{off}
\alias{on}
\alias{packrat-mode}
\alias{packrat_mode}
\title{Packrat Mode}
\usage{
packrat_mode(on = NULL, project = NULL, bootstrap = FALSE,
  auto.snapshot = get_opts("auto.snapshot"), clean.search.path = TRUE)

on(project = NULL, bootstrap = FALSE,
  auto.snapshot = get_opts("auto.snapshot"), clean.search.path = TRUE)

off(project = NULL)
}
\arguments{
\item{on}{Turn packrat mode on (\code{TRUE}) or off (\code{FALSE}). If omitted, packrat mode
will be toggled.}

\item{project}{The directory in which packrat mode is launched -- this is
where local libraries will be used and updated.}

\item{bootstrap}{Bootstrap a project that has not yet been packified?}

\item{auto.snapshot}{Perform automatic, asynchronous snapshots?}

\item{clean.search.path}{Detach and unload any packages loaded from non-system
libraries before entering packrat mode?}
}
\description{
Use these functions to switch \code{packrat} mode on and off. When within
\code{packrat} mode, the \R session will use the private library generated
for the current project.
}

