.onAttach <- function(libname, pkgname) {
  packageStartupMessage(.mc_disclaimer_banner())
}
