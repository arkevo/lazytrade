#' Record Reinforcement Learning Policy for Market Types
#'
#' @description Function will write a policy 'decision' to the csv file specific for each Expert Advisor
#'
#' @param x - Dataframe containing columns MarketType and Policy
#' @param trading_system - numeric vector of lenght 1 with Trading System Magic Number information
#' @param path_terminal - string, path to the terminal where this Policy/Decision must be written
#' @param fileName - string, desired control file prefix e.g. 'SystemControlMT'
#'
#' @return nothing is returned but function will write csv file to the supplied directory
#' @export
#'
#' @examples
#'
#'
#' library(stringr)
#' data(policy_tr_systDF)
#'
#' dir <- normalizePath(tempdir(),winslash = "/")
#'
#' record_policy_mt(x = policy_tr_systDF,
#'                  trading_system = 8118101,
#'                  path_terminal = dir,
#'                  fileName = "SystemControlMT")
#'
#'
record_policy_mt <- function(x, trading_system, path_terminal, fileName = "SystemControlMT"){
  requireNamespace("stringr", quietly = TRUE)

# derive which terminal should be enabled (using path to sandbox) and using variable 'addition'
  is_T3 <- str_detect(path_terminal, "Terminal3")
  is_T4 <- str_detect(path_terminal, "Terminal4")
  if(is_T3 == TRUE) { addition <- 200 } else if(is_T4 == TRUE) { addition <- 300 } else { addition <- 0 }

  # -------------------------
  # Write Decision/Update Policy
  # -------------------------
  # write the file for MQL4 usage
  composed_name <- paste0(fileName, as.character(trading_system + addition), ".csv")
  f_name <- file.path(path_terminal, composed_name)
  write.csv(x, file = f_name, quote = FALSE, row.names = FALSE)

}
