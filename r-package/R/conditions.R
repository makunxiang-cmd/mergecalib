.mc_condition_message <- function(...) {
  paste0(..., collapse = "")
}

.mc_error <- function(message, class, ..., call = NULL) {
  if (!is.character(class) || length(class) != 1L || !nzchar(class)) {
    stop("Internal error: condition class must be a non-empty string.", call. = FALSE)
  }
  structure(
    c(list(message = as.character(message), call = call), list(...)),
    class = unique(c(class, "mergecalib_error", "error", "condition"))
  )
}

.mc_stop <- function(class, ..., call = NULL) {
  stop(.mc_error(.mc_condition_message(...), class = class, call = call))
}

.mc_warning <- function(message, class, ..., call = NULL) {
  if (!is.character(class) || length(class) != 1L || !nzchar(class)) {
    stop("Internal error: warning class must be a non-empty string.", call. = FALSE)
  }
  structure(
    c(list(message = as.character(message), call = call), list(...)),
    class = unique(c(class, "mergecalib_warning", "warning", "condition"))
  )
}

.mc_warn <- function(class, ..., call = NULL) {
  if (identical(getOption("mergecalib.warn", TRUE), FALSE)) return(invisible(NULL))
  warning(.mc_warning(.mc_condition_message(...), class = class, call = call))
  invisible(NULL)
}

.mc_default_warning_thresholds <- function() {
  list(
    relaxation_delta = 0.02,
    max_weight_ratio = 5,
    heterogeneity = Inf,
    near_binding_margin = 0.005
  )
}

.mc_warning_thresholds <- function() {
  defaults <- .mc_default_warning_thresholds()
  user <- getOption("mergecalib.warning_thresholds", list())
  if (!is.list(user)) return(defaults)
  utils::modifyList(defaults, user)
}
