## internal environment storing metadata on the active shard
.shard <- new.env()
.shard$id <- NA

#' Run Kinesis Consumer application
#' @param initialize optional function to be run on startup. Please note that the variables created inside of this function will not be available to eg \code{processRecords}, so make sure to store the shared variables in the parent or global namespace
#' @param processRecords function to process records taking a \code{data.frame} object with \code{partitionKey}, \code{sequenceNumber} and \code{data} columns as the \code{records} argument. Probably you only need the \code{data} column from this object
#' @param shutdown optional function to be run when finished processing all records in a shard
#' @param checkpointing if set to \code{TRUE} (default), \code{kinesis_consumer} will checkpoint after each \code{processRecords} call. To disable checkpointing altogether, set this to \code{FALSE}. If you want to checkpoint periodically, set this to the frequency in minutes as integer.
#' @param updater optional list of list(s) including frequency (in minutes) and function to be run, most likely to update some objects in the parent or global namespace populated first in the \code{initialize} call. If the frequency is smaller than how long the \code{processRecords} call runs, it will be triggered once after each \code{processRecords} call
#' @param logfile file path of the log file. To disable logging, set \code{log_threshold} to something high with the \code{AWR.Kinesis} namespace
#' @export
#' @note Don't run this function directly, it is to be called by the MultiLangDaemon. See the package README for more details.
#' @references \url{https://github.com/awslabs/amazon-kinesis-client/blob/v1.x/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java}
#' @examples \dontrun{
#' log_threshold(FATAL, namespace = 'AWR.Kinesis')
#' AWS.Kinesis::kinesis_consumer(
#'   initialize = function() log_info('Loading some data'),
#'   processRecords = function(records) log_info('Received some records from Kinesis'),
#'   updater = list(list(1, function() log_info('Updating some data every minute')),
#'                  list(1/60, function() log_info('This is a high frequency updater call')))
#' )
#' }
kinesis_consumer <- function(initialize, processRecords, shutdown,
                             checkpointing = TRUE, updater, logfile = tempfile()) {

    ## store when we last checkpointed
    checkpoint_timestamp <- Sys.time()

    if (!missing(updater)) {

        ## check object structure
        if (!is.list(updater)) stop('The updater argument should be a list of list(s).')
        for (ui in 1:length(updater)) {
            if (!is.list(updater[[ui]])) stop(paste('The', ui, 'st/nd/th updater should be a list.'))
            if (length(updater[[ui]]) != 2) stop(paste('The', ui, 'st/nd/th updater should include 2 elements.'))
            if (!is.numeric(updater[[ui]][[1]])) stop(paste('The first element of the', ui, 'st/nd/th updater should be a numeric frequency.'))
            if (!is.function(updater[[ui]][[2]])) stop(paste('The second element of the', ui, 'st/nd/th updater should be a function.'))
        }

        ## init time for the updater functions
        updater_timestamps <- rep(Sys.time(), length(updater))

    }

    ## schedule garbage collection
    gc_timestamp <- Sys.time()

    ## log to file instead of stdout (which is used for communication with the Kinesis daemon)
    log_appender(appender_file(logfile))
    log_formatter(formatter_paste)
    log_info('Starting R Kinesis Consumer application')

    ## custom log layout to add shard ID in each log line
    log_layout(function(level, msg, ...) {
        timestamp <- format(Sys.time(), tz = 'UTC')
        sprintf("%s [%s UTC] %s %s", attr(level, 'level'), timestamp, .shard$id, msg)
    })

    ## run an infinite loop reading from stdin and writing to stout
    while (TRUE) {

        ## read and parse next message from stdin
        line <- read_line_from_stdin()

        ## init Kinesis consumer app
        if (line$action == 'initialize') {

            .shard$id <- line$shardId

            log_info('Start of initialize ')
            if (!missing(initialize)) {
                initialize()
            }
            log_info('End of initialize')

        }

        ## we are about to kill this process
        if (line$action == 'shutdown') {
            log_info('Shutting down')
            if (!missing(shutdown)) {
                shutdown()
            }
            if (line$reason == 'TERMINATE') {
                checkpoint()
            }
        }

        ## process records
        if (line$action == 'processRecords') {

            n <- nrow(line$records)
            log_debug(paste('Processing', n, 'records'))

            ## nothing to do right now
            if (n == 0) next()

            ## parse response into data.table
            records <- data.frame(
                partitionKey   = line$records$partitionKey,
                sequenceNumber = line$records$sequenceNumber,
                data           = sapply(line$records$data,
                                        function(x) rawToChar(base64_dec(x)), USE.NAMES = FALSE),
                stringsAsFactors = FALSE)

            ## do business logic
            processRecords(records)

            ## always checkpoint
            if (isTRUE(checkpointing)) {
                checkpoint()
            }

            ## checkpoint once every few minutes
            if (is.integer(checkpointing) && length(checkpointing) == 1 &&
                difftime(Sys.time(), checkpoint_timestamp, units = 'mins') > checkpointing) {

                log_debug('Time to checkpoint')
                checkpoint(line$records[nrow(line$records), 'sequenceNumber'])

                ## reset timer
                checkpoint_timestamp <- Sys.time()

            }

            ## updater functions
            if (!missing(updater)) {
                for (ui in 1:length(updater)) {
                    if (difftime(Sys.time(), updater_timestamps[ui], units = 'mins') > updater[[ui]][[1]]) {
                        log_debug(paste('Time to run updater', ui))
                        updater[[ui]][[2]]()
                        updater_timestamps[ui] <- Sys.time()
                    }
                }
            }

            ## just in case, garbage collection (once in every hour?)
            if (difftime(Sys.time(), gc_timestamp, units = 'mins') > 60) {
                invisible(gc())
            }

        }

        ## return response for action
        if (line$action != 'checkpoint') {
            write_line_to_stdout(toJSON(list(action = unbox('status'), responseFor = unbox(line$action))))
        }

        ## indeed shut down if this process is not needed any more
        if (line$action == 'shutdown') {
            quit(save = 'no', status = 0, runLast = FALSE)
        }

    }

}
