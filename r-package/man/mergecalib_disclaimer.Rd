\name{mergecalib_disclaimer}
\alias{mergecalib_disclaimer}
\title{Show the mergecalib disclaimer}
\usage{mergecalib_disclaimer(print = TRUE)}
\arguments{
\item{print}{If \code{TRUE} (default) the disclaimer is printed to the console.}
}
\value{Invisibly returns the disclaimer text as a single character string.}
\description{
Prints the full text of the package disclaimer, which describes the
responsibilities of the user when relying on the produced merge plans.
}
\seealso{\code{\link{mergecalib_agree}}}
\examples{
invisible(mergecalib_disclaimer(print = FALSE))
}
