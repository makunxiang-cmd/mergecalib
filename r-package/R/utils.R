.is_integerish <- function(x, tol = 1e-8) {
  is.numeric(x) && all(is.finite(x)) && all(abs(x - round(x)) <= tol)
}

.as_character_no_na <- function(x) {
  out <- as.character(x)
  out[is.na(out)] <- NA_character_
  out
}

## Values treated as "match all" in target specifications. "\u5168\u56fd" is the
## Chinese word for "national"; it is written as a unicode escape so the source
## stays ASCII-clean for CRAN.
.mc_wildcards <- function() c("", "*", "ALL", "all", "\u5168\u56fd")

.is_wildcard <- function(x) {
  is.na(x) | trimws(as.character(x)) %in% .mc_wildcards()
}

.safe_name <- function(x) {
  gsub("[^A-Za-z0-9_.-]+", "_", as.character(x))
}

.list_rbind <- function(x) {
  if (!length(x)) return(data.frame())
  cols <- unique(unlist(lapply(x, names), use.names = FALSE))
  x <- lapply(x, function(z) {
    miss <- setdiff(cols, names(z))
    for (nm in miss) z[[nm]] <- NA
    z[cols]
  })
  out <- do.call(rbind, lapply(x, as.data.frame, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
}

.lex_order <- function(...) {
  do.call(order, c(list(...), list(na.last = TRUE, method = "radix")))
}

.match_rows <- function(data, target, columns) {
  keep <- rep(TRUE, nrow(data))
  for (col in columns) {
    value <- target[[col]]
    if (!.is_wildcard(value)) {
      keep <- keep & as.character(data[[col]]) == as.character(value)
    }
  }
  keep
}

.assert_installed <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    .mc_stop(
      "mergecalib_error_internal",
      "The R package '", package, "' is required to solve the model. ",
      "Please run install.packages(\"", package, "\")."
    )
  }
}

.solution_available <- function(sol, nvar) {
  x <- sol$primal_solution
  !is.null(x) && length(x) == nvar && all(is.finite(x))
}

.status_is_optimal <- function(sol) {
  msg <- tolower(paste(sol$status_message, collapse = " "))
  grepl("optimal", msg, fixed = TRUE)
}

.compact_number <- function(x, digits = 6) {
  formatC(x, digits = digits, format = "fg", flag = "#")
}
