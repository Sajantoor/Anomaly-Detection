file <- "data/TermProjectDataFiltered.txt"
if (!file.exists(file)) {
  setwd(paste(getwd(), "term-project", sep = "/"))
}

data <- read.table(file, header = TRUE, sep = ",", dec = ".")
data[,] <- scale(data)

INTERVAL_LENGTH <- 3 * 60
TOTAL_INTERVALS <- dim(data)[1] / INTERVAL_LENGTH

TESTING_INTERVALS <- round(TOTAL_INTERVALS * 0.333)
TRAINING_INTERVALS <- TOTAL_INTERVALS - TESTING_INTERVALS

trainingData <- head(data, n = INTERVAL_LENGTH * TRAINING_INTERVALS)
testingData <- tail(data, n = INTERVAL_LENGTH * TESTING_INTERVALS)

# Get the data with injected anomalies ========================================

anomalyData1 <- read.table("data/DataWithAnomalies1Filtered.txt", header = TRUE, sep = ",", dec = ".")
anomalyData1[,] <- scale(anomalyData1)

anomalyData2 <- read.table("data/DataWithAnomalies2Filtered.txt", header = TRUE, sep = ",", dec = ".")
anomalyData2[,] <- scale(anomalyData2)

anomalyData3 <- read.table("data/DataWithAnomalies3Filtered.txt", header = TRUE, sep = ",", dec = ".")
anomalyData3[,] <- scale(anomalyData3)

# Main loop for training the model ============================================

library("depmixS4")
library("ggplot2")
library("tidyverse")

FEATURES <- list(Global_active_power ~ 1, Global_intensity ~ 1)
FAMILY <- list(gaussian(), gaussian())

MIN_STATES <- 4
MAX_STATES <- 24

makeModel = function(df, s) {
  m <- depmix(response = FEATURES, family = FAMILY, data = df, nstates = s,
              ntimes = rep(INTERVAL_LENGTH, dim(df)[1] / INTERVAL_LENGTH))
  return(m)
}

testModel = function(df, s, m) {
  tm <- makeModel(df, s)
  tm <- setpars(tm, getpars(m))
  ll <- forwardbackward(tm)$logLike / length(FEATURES) / dim(df)[1]
  return(ll)
}

logLikeDF <- data.frame(matrix(nrow = MAX_STATES - MIN_STATES + 1, ncol = 3))
colnames(logLikeDF) <- c("states", "Train", "Test")

BICDF <- data.frame(matrix(nrow = MAX_STATES - MIN_STATES + 1, ncol = 2))
colnames(BICDF) <- c("states", "BIC")

for (n in MAX_STATES:MIN_STATES) {
  cat("Fitting model with", n, "states:\n")
  set.seed(1)

  baseModel <- makeModel(trainingData, n)
  fittedModel <- fit(baseModel, verbose = TRUE, em = em.control(maxit = 9999))

  modelBIC <- BIC(fittedModel) / dim(trainingData)[1]
  cat("- Training resulted in a normalized BIC of", modelBIC, "\n")

  trainLogLike <- testModel(trainingData, n, fittedModel)
  cat("- Training converged at normalized logLike of", trainLogLike, "\n")

  testLogLike <- testModel(testingData, n, fittedModel)
  cat("- Testing resulted in normalized logLik of", testLogLike, "\n")

  logLikeDF[n - 3,] <- c(n, trainLogLike, testLogLike)
  BICDF[n - 3,] <- c(n, modelBIC)
  
  # Plot the train/test data ==================================================

  # The following line inspired by this StackOverflow thread:
  # https://stackoverflow.com/questions/7570319/the-right-way-to-plot-multiple-y-values-as-separate-lines-with-ggplot2
  logLikeDF.long <- logLikeDF %>% 
    pivot_longer(-states, names_to = "name", values_to = "logLike")
  
  plot <- ggplot(data = logLikeDF.long) +
    aes(x = states, y = logLike, colour = name) +
    geom_line(size = 1) +
    ylab("Normalized Log-Likelihood") +
    xlab("Number of States") +
    theme(legend.position = "right") +
    guides(colour = guide_legend(title = "Legend"))
  print(plot)

  # Plot the model complexity data ============================================

  plot <- ggplot(data = BICDF) +
    aes(x = states, y = BIC) +
    geom_line(size = 1) +
    ylab("Normalized BIC") +
    xlab("Number of States")
  print(plot)
}
