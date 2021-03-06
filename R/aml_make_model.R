#' Function to train Deep Learning regression model for a single currency pair
#'
#' @description  Function is training h2o deep learning model to match future prices of the asset to the indicator pattern.
#' Main idea is to be able to predict future prices by solely relying on the most recent indicator pattern.
#' This is to mimic traditional algorithmic systems based on the indicator rule attempting to automate optimization process with AI.
#'
#' Deep learning model structure is obtained from the 6 random combinations of neurons within 4 layers of the network,
#' the most accurate model configuration will be automatically selected
#'
#' In addition the function will check if there is a need to update the model. To do that function will check
#' results of the function aml_test_model.R.
#'
#' @details Function is using the dataset prepared by the function aml_collect_data.R.
#' Function will start to train the model as soon as there are more than 100 rows in the dataset
#'
#'
#'
#' @author (C) 2019 Vladimir Zhbanko
#'
#' @param symbol              Character symbol of the asset for which to train the model
#' @param num_bars            Number of bars used to detect pattern
#' @param timeframe           Data timeframe e.g. 1 min
#' @param path_model          Path where the models are be stored
#' @param path_data           Path where the aggregated historical data is stored, if exists in rds format
#' @param force_update        Boolean, by setting this to TRUE function will generate new model
#'                            (useful after h2o engine update)
#'
#' @return Function is writing file object with the model
#' @export
#'
#' @examples
#'
#' \donttest{
#'
#'
#' library(dplyr)
#' library(readr)
#' library(h2o)
#' library(lazytrade)
#'
#' path_model <- normalizePath(tempdir(),winslash = "/")
#' path_data <- normalizePath(tempdir(),winslash = "/")
#'
#' data(EURUSDM15X75)
#' write_rds(EURUSDM15X75, file.path(path_data, 'EURUSDM15X75.rds'))
#'
#' # start h2o engine (using all CPU's by default)
#' h2o.init()
#'
#'
#' # performing Deep Learning Regression using the custom function
#' aml_make_model(symbol = 'EURUSD',
#'                num_bars = 75,
#'                timeframe = 15,
#'                path_model = path_model,
#'                path_data = path_data)
#'
#' # stop h2o engine
#' h2o.shutdown(prompt = F)
#'
#' }
#'
#'
#'
aml_make_model <- function(symbol, num_bars, timeframe, path_model, path_data,
                           force_update=FALSE){

  requireNamespace("dplyr", quietly = TRUE)
  requireNamespace("readr", quietly = TRUE)
  requireNamespace("h2o", quietly = TRUE)

  ### check if it's actually required to make a model: e.g. if model is tested and results are good...
  ## recover the file name and path
  dec_file_name <- paste0("StrTest-", symbol, "M",timeframe,"X",num_bars, ".csv")
  dec_file_path <- file.path(path_model,  dec_file_name)

  # generate a file name for model
  m_name <- paste0("DL_Regression", "-", symbol,"-", num_bars, "-", timeframe)
  m_path <- file.path(path_model, m_name)

  ## read the file and the status of the model
  if(file.exists(dec_file_path) && force_update == FALSE){
    # read the file
    model_status <- read_csv(dec_file_path) %>% select(FinalQuality)
  } else if(force_update == TRUE) {
    # delete the model and previous test results
    remove(dec_file_path)
    remove(m_path)
    model_status <- -1
  } else { model_status <- 0 }

  #construct the path to the data object see function aml_collect_data.R
  # generate a file name
  f_name <- paste0(symbol, "M",timeframe,"X",num_bars, ".rds")
  full_path <- file.path(path_data,  f_name)

  x <- try(read_rds(full_path), silent = T)



  # proceed with further steps only if model status is < 0 and there are enough data in x
  if(model_status < 0 || (!file.exists(m_path) && nrow(x) > 100)) {

  # split data to train and test blocks
  # note: model will be tested on the PAST data and trained on the NEWEST data
  test_ind  <- 1:round(0.3*(nrow(x))) #train indices 1:xxx
  dat21 <- x[test_ind, ]    #dataset to test the model using 30% of data
  dat22 <- x[-test_ind, ]   #dataset to train the model

  ## ---------- Data Modelling  ---------------
  #h2o.init()

  ### random network structure
  nn_sets <- sample.int(n = 200, 24) %>% matrix(ncol = 4)

  ###

  # load data into h2o environment
  #macd_ML  <- as.h2o(x = dat22, destination_frame = "macd_ML")
  macd_ML  <- as.h2o(x = x, destination_frame = "macd_ML")

  # for loop to select the best neural network structure

  for (i in 1:dim(nn_sets)[1]) {

    # i <- 1
    # fit models from simplest to more complex
  ModelC <- h2o.deeplearning(
    model_id = paste0("DL_Regression", "-", symbol, "-", num_bars, "-", timeframe),
    x = names(macd_ML[,2:num_bars+1]),
    y = "LABEL",
    training_frame = macd_ML,
    activation = "Tanh",
    overwrite_with_best_model = TRUE,
    autoencoder = FALSE,
    hidden = nn_sets[i, ],
    loss = "Automatic",
    sparse = TRUE,
    l1 = 1e-4,
    distribution = "AUTO",
    stopping_metric = "MSE",
    #balance_classes = F,
    epochs = 100)

  #ModelC
  #summary(ModelC)
  RMSE <- h2o.performance(ModelC)@metrics$RMSE %>% as.data.frame()
  names(RMSE) <- 'RMSE'

  # record results of modelling
  if(!exists("df_res")){
    df_res <- nn_sets[i,] %>% t() %>% as.data.frame() %>% bind_cols(RMSE)
  } else {
    df_row <- nn_sets[i,] %>% t() %>% as.data.frame() %>% bind_cols(RMSE)
    df_res <- df_res %>% bind_rows(df_row)
  }


  } # end of for loop

  ## retrain and save the best model
  #what is the most accurate model?
  # find which row in the df_res has the smallest RMSE value
  lowest_RMSE <- df_res %>% arrange(desc(RMSE)) %>% tail(1) %>% row.names() %>% as.integer()

  # train the model again:
  ModelC <- h2o.deeplearning(
    model_id = paste0("DL_Regression", "-", symbol, "-", num_bars, "-", timeframe),
    x = names(macd_ML[,2:num_bars+1]),
    y = "LABEL",
    training_frame = macd_ML,
    activation = "Tanh",
    overwrite_with_best_model = TRUE,
    autoencoder = FALSE,
    hidden = nn_sets[lowest_RMSE, ],
    loss = "Automatic",
    sparse = TRUE,
    l1 = 1e-4,
    distribution = "AUTO",
    stopping_metric = "MSE",
    #balance_classes = F,
    epochs = 100)


  # save model object
  h2o.saveModel(ModelC, path = path_model, force = T)
}
  #h2o.shutdown(prompt = FALSE)


}

