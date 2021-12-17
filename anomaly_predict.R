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

# Comment this block after running it once or else it takes too long.
NUM_STATES <- 24
set.seed(1)
baseModel <- makeModel(trainingData, NUM_STATES)
fittedModel <- fit(baseModel, verbose = TRUE, em = em.control(maxit = 9999))

# This function assumes fittedModel is a fitted model with NUM_STATES states.
getIndividualLL <- function(df) {
  num_intervals <- dim(df)[1] / INTERVAL_LENGTH
  intervalLLs <- numeric(num_intervals)
  for (i in 1:num_intervals * INTERVAL_LENGTH) {
    start_index <- i - INTERVAL_LENGTH + 1
    logLike <- testModel(df[start_index:i,], NUM_STATES, fittedModel)
    intervalLLs[i / INTERVAL_LENGTH] <- logLike
  }
  return(intervalLLs)
}

testingLLs <- getIndividualLL(testingData)
testingLLs <- data.frame(rep(" Test ", length(testingLLs)), testingLLs)
colnames(testingLLs) <- c("run", "logLike")

anomaly1LLs <- getIndividualLL(anomalyData1)
anomaly1LLs <- data.frame(rep("Anom1", length(anomaly1LLs)), anomaly1LLs)
colnames(anomaly1LLs) <- c("run", "logLike")

anomaly2LLs <- getIndividualLL(anomalyData2)
anomaly2LLs <- data.frame(rep("Anom2", length(anomaly2LLs)), anomaly2LLs)
colnames(anomaly2LLs) <- c("run", "logLike")

anomaly3LLs <- getIndividualLL(anomalyData3)
anomaly3LLs <- data.frame(rep("Anom3", length(anomaly3LLs)), anomaly3LLs)
colnames(anomaly3LLs) <- c("run", "logLike")

allDataLLs <- rbind(testingLLs, anomaly1LLs, anomaly2LLs, anomaly3LLs)

plot <- ggplot(data = allDataLLs) +
  aes(x = run, y = logLike, color = run) +
  geom_point(alpha = 0.5) +
  ylab("Normalized Log-Likelihood") +
  xlab("") +
  theme(legend.position = "none")
print(plot)

# This part finds the "optimal" threshold cutoff for determining anomalies.
# Tweak FP_COEFF and FN_COEFF to configure how much the false positive and
# false negative rates are valued respectively.
# As a guideline, it may be easier to think of FP_COEFF to be the ratio of
# time intervals where there is not an anomaly to the number of times there is
# an anomaly, and to think of FN_COEFF to be the ratio between the cost of a
# false negative to the cost of a false positive.
FP_COEFF <- 1
FN_COEFF <- 1

bestScore <- FP_COEFF + FN_COEFF
bestThreshold <- NA
bestFP <- NA
bestFN <- NA

sortedTestingLLs <- sort(testingLLs[,2])
for (i in 1:length(sortedTestingLLs)) {
  percentFP <- (i - 1) / length(sortedTestingLLs)
  FN1 <- sum(anomaly1LLs[,2] >= sortedTestingLLs[i])
  FN2 <- sum(anomaly2LLs[,2] >= sortedTestingLLs[i])
  FN3 <- sum(anomaly3LLs[,2] >= sortedTestingLLs[i])
  percentFN <- (FN1 + FN2 + FN3) / (dim(anomaly1LLs)[1] + dim(anomaly2LLs)[1] + dim(anomaly3LLs)[1])

  score = FP_COEFF * percentFP + FN_COEFF * percentFN
  if (score < bestScore) {
    bestScore <- score
    bestThreshold <- sortedTestingLLs[i]
    bestFP <- percentFP
    bestFN <- percentFN
  }
}

cat("Threshold:", bestThreshold)
cat("F(+)> ", round(100 * bestFP, 1), "%\n", sep = "")
cat("F(-)> ", round(100 * bestFN, 1), "%\n", sep = "")
