#' Read one non-empty line from stdin without any warnings printed to stdout
#' @return string
#' @keywords internal
read_line_from_stdin <- function() {

    ## load stdin only once per R session to avoid the memory leak with
    ## always re-opening the connection
    if (is.null(stdincon)) {
        assignInMyNamespace(
            'stdincon',
            suppressWarnings(file('stdin', open = 'r', blocking = TRUE)))
    }

    ## stdincon was opened at package load
    line <- scan(stdincon, what = character(0), nlines = 1, quiet = TRUE)

    ## empty line received
    if (length(line) == 0) {
        Sys.sleep(0.25)
        log_trace('Nothing read from stdin, looking for new messages...')
        return(eval.parent(match.call()))
    }

    ## return parsed line with logging
    log_trace(paste0('Read ', nchar(line), ' char(s) from stdin: ',
                     substr(line, 1, 500), ifelse(nchar(line) > 500, ' ...', '')))
    return(fromJSON(line))

}

#' Securely write a line to stdout with logging
#' @param line string
#' @keywords internal
write_line_to_stdout <- function(line) {
    flush(stdout())
    log_trace(paste('Writing to stdout:', line))
    cat('\n\n', line, '\n\n')
    flush(stdout())
}
