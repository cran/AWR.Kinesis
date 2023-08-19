#' An R Kinesis Consumer
#'
#' Please find more details in the \code{README.md} file.
#' @docType package
#' @importFrom logger log_trace log_debug log_info log_appender log_formatter formatter_paste appender_file log_layout
#' @importFrom jsonlite fromJSON toJSON base64_dec base64_enc unbox
#' @importFrom rJava .jnew J .jbyte
#' @importFrom utils assignInMyNamespace
#' @import AWR
#' @name AWR.Kinesis-package
NULL

## connection to be opened in the first call to read_line_from_stdin
stdincon <- NULL

.onUnload <- function(libpath) {

    ## close opened connection
    if (!is.null(stdincon)) {
        close(stdincon)
    }

}
