## --------------------------------------------------------------------------
## User disclaimer and consent
##
## mergecalib performs a statistical optimisation. The merge plans it produces
## must be reviewed by a qualified statistician before use. To make that
## responsibility explicit, the package asks the user to acknowledge a short
## disclaimer before the first model is fitted in an interactive session.
##
## The mechanism is deliberately CRAN-safe:
##   * It never blocks non-interactive use (R CMD check, scripts, CI,
##     vignettes); in that case it proceeds and emits a single message.
##   * It never writes to the user's filespace.
##   * Consent is stored only for the current session via options().
## --------------------------------------------------------------------------

#' Show the mergecalib disclaimer
#'
#' Prints the full text of the package disclaimer, which describes the
#' responsibilities of the user when relying on the produced merge plans.
#'
#' @param print If `TRUE` (default) the disclaimer is sent to the console.
#' @return Invisibly returns the disclaimer text as a single character string.
#' @seealso [mergecalib_agree()]
#' @examples
#' invisible(mergecalib_disclaimer(print = FALSE))
#' @export
mergecalib_disclaimer <- function(print = TRUE) {
  text <- .mc_disclaimer_text()
  if (isTRUE(print)) cat(text, sep = "\n")
  invisible(paste(text, collapse = "\n"))
}

#' Record agreement with the mergecalib disclaimer
#'
#' Records, for the current R session only, whether the user agrees with the
#' package disclaimer. Once agreement is recorded, [fit_merge_calibration()]
#' does not prompt again during the session. Agreement is stored in
#' `options(mergecalib.agreed = ...)` and is not written to disk.
#'
#' @param agree Logical; `TRUE` to record agreement, `FALSE` to withdraw it.
#' @return Invisibly returns the logical agreement value.
#' @seealso [mergecalib_disclaimer()]
#' @examples
#' old <- getOption("mergecalib.agreed")
#' mergecalib_agree(TRUE)
#' mergecalib_agree(FALSE)
#' options(mergecalib.agreed = old)
#' @export
mergecalib_agree <- function(agree = TRUE) {
  agree <- isTRUE(agree)
  options(mergecalib.agreed = agree)
  if (agree) {
    message("mergecalib: disclaimer acknowledged for this session.")
  } else {
    message("mergecalib: disclaimer agreement withdrawn for this session.")
  }
  invisible(agree)
}

## Internal: full disclaimer text (English). Falls back to a built-in copy if
## the installed DISCLAIMER.md cannot be located.
.mc_disclaimer_text <- function() {
  path <- system.file("DISCLAIMER.md", package = "mergecalib")
  if (nzchar(path) && file.exists(path)) {
    return(readLines(path, encoding = "UTF-8", warn = FALSE))
  }
  c(
    "mergecalib DISCLAIMER",
    "",
    "mergecalib is a statistical computation and optimisation tool. Users are",
    "responsible for confirming that target intervals, demographic variable",
    "definitions, weight semantics, and merging rules match the statistical",
    "design, business rules, and legal requirements of their own project.",
    "",
    "The package does not create observations for populations with no observed",
    "sample, and under its default rules it never borrows sample across",
    "provinces. Target feasibility does not imply unbiased estimation: the",
    "merge scope, outcome heterogeneity, and final weight changes must still be",
    "reviewed by the responsible statistician. The software is provided \"as is\",",
    "without warranty of any kind."
  )
}

## Internal: short banner shown on attach and at the first interactive fit.
.mc_disclaimer_banner <- function() {
  paste(
    c(
      "mergecalib produces statistical merge plans that MUST be reviewed by a",
      "qualified statistician before use. Target feasibility does not imply",
      "unbiased estimation. See mergecalib_disclaimer() for the full text.",
      "By continuing you accept the disclaimer. Use mergecalib_agree() to",
      "acknowledge it once per session and skip this prompt."
    ),
    collapse = "\n"
  )
}

## Internal: gate called at the start of fit_merge_calibration().
.mc_require_consent <- function() {
  if (isTRUE(getOption("mergecalib.agreed"))) {
    return(invisible(TRUE))
  }
  ## Non-interactive use (R CMD check, scripts, CI, vignettes) must never block.
  if (!interactive()) {
    if (!isTRUE(getOption("mergecalib.consent_notice_shown"))) {
      message(
        "mergecalib: proceeding under the package disclaimer ",
        "(see mergecalib_disclaimer())."
      )
      options(mergecalib.consent_notice_shown = TRUE)
    }
    return(invisible(TRUE))
  }
  ## Interactive use: ask once.
  message(.mc_disclaimer_banner())
  ans <- tryCatch(
    utils::menu(c("I agree", "I do not agree"), title = "Do you accept the mergecalib disclaimer?"),
    error = function(e) 0L
  )
  if (identical(as.integer(ans), 1L)) {
    options(mergecalib.agreed = TRUE)
    return(invisible(TRUE))
  }
  .mc_stop(
    "You must accept the mergecalib disclaimer to fit a model. ",
    "Call mergecalib_agree(TRUE) or re-run and choose \"I agree\"."
  )
}
