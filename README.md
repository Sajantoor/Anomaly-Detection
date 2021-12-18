# Anomaly Detection

Term project for CMPT 318 - Cybersecurity

## About

The threat of cyberattacks is growing rapidly.
Threats are becoming more complex, sophisticated and difficult to detect.
Power grids are vital to the security and health of our society and nation, and
are at risk of cyberattacks.
This project aims to detect anomalies in power grid data using Hidden Markov
Models.
Preventing cyberattacks on power grids and allow systems or engineers to promptly
take further action to prevent damage to the power grid.

## Description of Files

**report/report.pdf**

The PDF which holds the term project report

**presentation/CMPT 318 Presentation.pdf**

Slides for the term project presentation

**preprocess_data.py**

Python script that does the data preprocesing - Parses the provided data files - Runs Principal Component Analysis on the entire data set - Plots various charts related to the Principal Component Analysis - Filters out the wanted time intervals - Interpolates or removes the missing data values - Saves the processed data into a sepearte file for future use

**train_data.R**

R script that trains multiple Hidden Markov Models - Loads the data filtered by the preprocessing script - Splits the normal data into training and testing data sets - Trains 21 models with states in the range 4–24 - Plots a graph of the normalized log likelihood of each model on both the
training and testing data sets - Plots a graph of the Bayesian Information Criterion values for each model

**anomaly_predict.R**

R script that predicts anomalies with trained models - Loads the data filtered by the preprocessing script - Tests the trained model on each interval of the testing and anomalous
data individually to find the log likelihood of each interval - Plots a graph showing the distribution of log likelihoods for individual
time intervals of the test and all three anomaly data sets - Calculates the optimal log likelihood threshold for anomalies given some
context about the value of false positives and false negatives

**point_anomalies.R**

R script that finds threshold values for point anomalies - Loads the data filtered by the preprocessing script - From the training data finds the average of each minute in the interval,
this is an average normal interval - Then calculate the average difference between the average of each normal
interval and the anomaly observation - Use this information to find thresholds for point anomalies from the testing dataset,
because we don't know the actual number of point anomalies in the testing dataset, we have
to make a guess. - Find point anomalies by comparing the difference value to the thresholds with
the anomaly datasets.
