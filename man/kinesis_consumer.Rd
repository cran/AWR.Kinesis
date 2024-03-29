% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/consumer.R
\name{kinesis_consumer}
\alias{kinesis_consumer}
\title{Run Kinesis Consumer application}
\usage{
kinesis_consumer(
  initialize,
  processRecords,
  shutdown,
  checkpointing = TRUE,
  updater,
  logfile = tempfile()
)
}
\arguments{
\item{initialize}{optional function to be run on startup. Please note that the variables created inside of this function will not be available to eg \code{processRecords}, so make sure to store the shared variables in the parent or global namespace}

\item{processRecords}{function to process records taking a \code{data.frame} object with \code{partitionKey}, \code{sequenceNumber} and \code{data} columns as the \code{records} argument. Probably you only need the \code{data} column from this object}

\item{shutdown}{optional function to be run when finished processing all records in a shard}

\item{checkpointing}{if set to \code{TRUE} (default), \code{kinesis_consumer} will checkpoint after each \code{processRecords} call. To disable checkpointing altogether, set this to \code{FALSE}. If you want to checkpoint periodically, set this to the frequency in minutes as integer.}

\item{updater}{optional list of list(s) including frequency (in minutes) and function to be run, most likely to update some objects in the parent or global namespace populated first in the \code{initialize} call. If the frequency is smaller than how long the \code{processRecords} call runs, it will be triggered once after each \code{processRecords} call}

\item{logfile}{file path of the log file. To disable logging, set \code{log_threshold} to something high with the \code{AWR.Kinesis} namespace}
}
\description{
Run Kinesis Consumer application
}
\note{
Don't run this function directly, it is to be called by the MultiLangDaemon. See the package README for more details.
}
\examples{
\dontrun{
log_threshold(FATAL, namespace = 'AWR.Kinesis')
AWS.Kinesis::kinesis_consumer(
  initialize = function() log_info('Loading some data'),
  processRecords = function(records) log_info('Received some records from Kinesis'),
  updater = list(list(1, function() log_info('Updating some data every minute')),
                 list(1/60, function() log_info('This is a high frequency updater call')))
)
}
}
\references{
\url{https://github.com/awslabs/amazon-kinesis-client/blob/v1.x/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java}
}
