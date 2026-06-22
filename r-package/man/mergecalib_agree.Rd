\name{mergecalib_agree}
\alias{mergecalib_agree}
\title{Record agreement with the mergecalib disclaimer}
\usage{mergecalib_agree(agree = TRUE)}
\arguments{
\item{agree}{Logical; \code{TRUE} to record agreement, \code{FALSE} to withdraw it.}
}
\value{Invisibly returns the logical agreement value.}
\description{
Records, for the current R session only, whether the user agrees with the
package disclaimer. Once agreement is recorded, \code{fit_merge_calibration()}
does not prompt again during the session. Agreement is stored in
\code{options(mergecalib.agreed = ...)} and is not written to disk.
}
\seealso{\code{\link{mergecalib_disclaimer}}}
\examples{
old <- getOption("mergecalib.agreed")
mergecalib_agree(TRUE)
mergecalib_agree(FALSE)
options(mergecalib.agreed = old)
}
