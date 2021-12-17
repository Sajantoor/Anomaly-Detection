file <- "data/TermProjectDataFiltered.txt"
if (!file.exists(file)) {
    setwd(paste(getwd(), "term-project", sep = "/"))
}

data <- read.table(file, header = TRUE, sep = ",", dec = ".")

INTERVAL_LENGTH <- 3 * 60
TOTAL_INTERVALS <- dim(data)[1] / INTERVAL_LENGTH

TESTING_INTERVALS <- round(TOTAL_INTERVALS * 0.3)
TRAINING_INTERVALS <- TOTAL_INTERVALS - TESTING_INTERVALS

training_data <- head(data, n = INTERVAL_LENGTH * TRAINING_INTERVALS)

# compute the average of each interval in the training data
average_int <- matrix(nrow = INTERVAL_LENGTH, ncol = 2)

# compute the average for each minute in the data
# min: minute
# feature: the feature in the data
# num_intervals: the number of intervals in the data
average_min <- function(data, min, feature, num_intervals) {
    sum <- 0
    length <- length(data[, feature])
    i <- 0

    # loop through all intevals in the data until we reach the end of the data
    while (min + (i * INTERVAL_LENGTH) <= length) {
        sum <- sum + data[min + (i * INTERVAL_LENGTH), feature]
        i <- i + 1
    }

    # return the average of the minute i
    return(sum / num_intervals)
}

# compute the average for both of our features, Global_active_power and Global_
# intensity over one interval
for (i in 1:INTERVAL_LENGTH) {
    # feature 1 is Global_active_power
    average_int[i, 1] <- average_min(training_data, i, 1, TRAINING_INTERVALS)
    # feature 4 is Global_intensity
    average_int[i, 2] <- average_min(training_data, i, 4, TRAINING_INTERVALS)
}

# instead of guessing thresholds, since we have a lot of data and mostly no
# anomalies in the data, we can average the differences between the average
# intervals and anomalous data
calculate_avg_diff <- function(average_int, anomaly_data) {
    anomaly_length <- length(anomaly_data[, 1])
    min <- 0
    avg_diff <- c(0, 0)
    anomaly_length <- length(anomaly_data[, 1])

    # for each minute in the anomaly data calculate the difference between the
    # average interval and the anomaly data and add it to avg_diff
    for (i in 1:anomaly_length) {
        min <- i %% INTERVAL_LENGTH + 1
        current_diff <- anomaly_data[i, 1] - average_int[min, 1]
        current_diff2 <- anomaly_data[i, 4] - average_int[min, 2]

        avg_diff[1] <- avg_diff[1] + current_diff
        avg_diff[2] <- avg_diff[2] + current_diff2
    }

    # return the average difference for each feature
    avg_diff[1] <- avg_diff[1] / anomaly_length
    avg_diff[2] <- avg_diff[2] / anomaly_length
    return(avg_diff)
}


# now we have the average of each minute in the interval in the training data
# we can now get point anomalies for each minute in the data

# find point anomalies for each minute in the data
# feature -> 1 to find thresholds for feature 1, 2 to find thresholds for feature 2
find_point_anomalies <- function(average_int, anomaly_data, threshold, feature) {
    max_threshold_gap <- threshold[1]
    min_threshold_gap <- threshold[2]
    max_threshold_gi <- threshold[3]
    min_threshold_gi <- threshold[4]

    min <- 0
    anomaly_length <- length(anomaly_data[, 1])
    anomalous_status <- matrix(nrow = anomaly_length, ncol = 1)

    for (i in 1:anomaly_length) {
        min <- i %% INTERVAL_LENGTH + 1
        difference_gap <- anomaly_data[i, 1] - average_int[min, 1]
        difference_gi <- anomaly_data[i, 4] - average_int[min, 2]

        # if it is anomalous, then we set the anomalous_status to 1
        anomalous_status[i, 1] <- 1


        if (feature != 2) {
            if (max_threshold_gap > difference_gap && difference_gap > min_threshold_gap) {
                anomalous_status[i, 1] <- 0
            }
        } else if (feature != 1) {
            if (max_threshold_gi > difference_gi && difference_gi > min_threshold_gi) {
                anomalous_status[i, 1] <- 0
            }
        }
    }

    return(anomalous_status)
}

# find the anomalous thresholds that minimize number of anomalies
# feature -> 1 to find thresholds for feature 1, 2 to find thresholds for feature 2
find_thresholds <- function(average_int, anomaly_data, feature) {
    # initialize the thresholds to the average difference
    # initialize the number of anomalies to length
    length <- length(anomaly_data[, 1])
    num_anomalies <- length

    # initialize the number of iterations to 0
    i <- 0
    avg_diff <- calculate_avg_diff(average_int, anomaly_data)
    thresholds <- c(0, 0)
    thresholds[1] <- avg_diff[1] # max threshold of GAP
    thresholds[2] <- avg_diff[1] # min threshold of GAP
    thresholds[3] <- avg_diff[2] # max threshold of GI
    thresholds[4] <- avg_diff[2] # min threshold of GI

    # loop until we have found the best thresholds
    # the number is the guess for number of anomalies in the training dataset
    while (num_anomalies > 50) {
        # update the number of anomalies
        status <- find_point_anomalies(average_int, anomaly_data_1, thresholds, feature)
        num_anomalies <- 0

        # count number of anomalies in status
        for (j in 1:length) {
            if (status[j, 1] == 1) {
                num_anomalies <- num_anomalies + 1
            }
        }

        # update the thresholds
        if (feature == 1) {
            thresholds[1] <- thresholds[1] + abs(avg_diff[1] * 0.2)
            thresholds[2] <- thresholds[2] - abs(avg_diff[1] * 0.2)
            cat(sprintf("%.0f - %g - %g - %.0f \n", num_anomalies, thresholds[1], thresholds[2], i))
        } else if (feature == 2) {
            thresholds[3] <- thresholds[3] + abs(avg_diff[2] * 0.2)
            thresholds[4] <- thresholds[4] - abs(avg_diff[2] * 0.2)
            cat(sprintf("%.0f - %g - %g - %.0f \n", num_anomalies, thresholds[3], thresholds[4], i))
        }
        # increment the number of iterations
        i <- i + 1
    }

    # return the thresholds
    return(thresholds)
}

# Find the thresholds for both features using the testing dataset
testingData <- tail(data, n = INTERVAL_LENGTH * TESTING_INTERVALS)
print("Finding thresholds for feature 1")
thresholds_1 <- find_thresholds(average_int, anomaly_data_1, 1)
print("Finding thresholds for feature 2")
thresholds_2 <- find_thresholds(average_int, anomaly_data_1, 2)

thresholds <- c(0, 0, 0, 0)
thresholds[1] <- thresholds_1[1]
thresholds[2] <- thresholds_1[2]
thresholds[3] <- thresholds_2[1]
thresholds[4] <- thresholds_2[2]

# get anomalous data sets
anomaly_data_1 <- read.table("data/DataWithAnomalies1Filtered.txt", header = TRUE, sep = ",", dec = ".")
status1 <- find_point_anomalies(average_int, anomaly_data_1, thresholds, 0)
cat("Number of point anomalies in anomalies dataset 1: ", sum(status1), "\n")

anomaly_data_2 <- read.table("data/DataWithAnomalies2Filtered.txt", header = TRUE, sep = ",", dec = ".")
status2 <- find_point_anomalies(average_int, anomaly_data_2, thresholds, 0)
cat("Number of point anomalies in anomalies dataset 2: ", sum(status2), "\n")


anomaly_data_3 <- read.table("data/DataWithAnomalies3Filtered.txt", header = TRUE, sep = ",", dec = ".")
status3 <- find_point_anomalies(average_int, anomaly_data_3, thresholds, 1)
cat("Number of point anomalies in anomalies dataset 3: ", sum(status3), "\n")