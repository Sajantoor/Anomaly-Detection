import datetime
import matplotlib.pyplot
import numpy
import pandas
import sklearn.decomposition
import sklearn.preprocessing

INPUT_FILE = "data/TermProjectData.txt"
OUTPUT_FILE = "data/TermProjectDataFiltered.txt"
# INPUT_FILE = "data/DataWithAnomalies1.txt"
# OUTPUT_FILE = "data/DataWithAnomalies1Filtered.txt"

# READ AND PARSE THE DATA FILE ================================================

# Set as time for Moon to circle Earth because that's funny. :)
MOON_WAVELENGTH = int(60 * 24 * 29.530588)
MOON_WAVELENGTH *= 3  # except it three times! O_o

with open(INPUT_FILE, "r") as fp:
    data_lines = fp.read().strip("\n").split("\n")
column_names = [s[1: -1] for s in data_lines.pop(0).split(",")]

raw_data = []
na_max = [0 for _ in range(len(column_names[2:]))]
na_length = [0 for _ in range(len(column_names[2:]))]
for i, line in enumerate(data_lines):
    line_data = line.split(",")[2:]

    for j, x in enumerate(line_data):
        try:
            line_data[j] = float(x)
            na_length[j] = 0
        except ValueError:
            line_data[j] = numpy.nan
            na_length[j] += 1
            na_max[j] = max(na_max[j], na_length[j])
    raw_data.append(line_data)

    if i % MOON_WAVELENGTH == 0:
        date_, time_ = [s[1: -1] for s in line.split(",")[:2]]
        date_ = "/".join(s.rjust(2, "0") for s in date_.split("/"))
        print("Parsing", date_, time_, "...")

print("Longest chain of NA values:", max(na_max))

START_TIME = datetime.datetime.strptime(
    "".join(data_lines[0].split(",")[:2]), '"%d/%m/%Y""%H:%M:%S"')
END_TIME = datetime.datetime.strptime(
    "".join(data_lines[-1].split(",")[:2]), '"%d/%m/%Y""%H:%M:%S"')

dates_only = pandas.date_range(START_TIME, END_TIME, freq="T")
assert len(dates_only) == len(raw_data)

df = pandas.DataFrame(raw_data, columns=column_names[2:], index=dates_only)
# print(df)

# RUN PRINCIPAL COMPONENT ANALYSIS ============================================

NUM_PC = len(column_names[2:])

pca_data = sklearn.preprocessing.StandardScaler().fit_transform(df.dropna())
pca = sklearn.decomposition.PCA(n_components=NUM_PC)
pca_data = pca.fit_transform(pca_data)
# print(pca.explained_variance_ratio_)

pca_df = pandas.DataFrame(pca.components_, columns=df.columns, index=[f"PC{i + 1}" for i in range(NUM_PC)])
# print(pca_df)

data_df = pandas.DataFrame(pca_data, columns=[f"PC{i + 1}" for i in range(NUM_PC)])
# print(data_df)

# PLOT A BUNCH OF GRAPHS! =====================================================

matplotlib.pyplot.bar(pca_df.index, 100 * pca.explained_variance_ratio_)
matplotlib.pyplot.ylabel("Percentage of Variance (%)")
matplotlib.pyplot.show()
matplotlib.pyplot.clf()

x_labels = ["GActP", "GReactP", "Voltage", "GInt", "SM1", "SM2", "SM3"]
matplotlib.pyplot.bar(x_labels, pca_df.iloc[0])
matplotlib.pyplot.ylabel("Factor in PC1")
matplotlib.pyplot.show()
matplotlib.pyplot.clf()

matplotlib.pyplot.bar(x_labels, pca_df.iloc[1])
matplotlib.pyplot.ylabel("Factor in PC2")
matplotlib.pyplot.show()
matplotlib.pyplot.clf()

matplotlib.pyplot.scatter(data_df["PC1"], data_df["PC2"], s=1, alpha=0.1)
matplotlib.pyplot.xlabel(f"PC1 ({100 * pca.explained_variance_ratio_[0]:.1f}%)")
matplotlib.pyplot.ylabel(f"PC2 ({100 * pca.explained_variance_ratio_[1]:.1f}%)")
matplotlib.pyplot.show()
matplotlib.pyplot.clf()

matplotlib.pyplot.scatter(data_df["PC2"], data_df["PC3"], s=1, alpha=0.1)
matplotlib.pyplot.xlabel(f"PC2 ({100 * pca.explained_variance_ratio_[1]:.1f}%)")
matplotlib.pyplot.ylabel(f"PC3 ({100 * pca.explained_variance_ratio_[2]:.1f}%)")
matplotlib.pyplot.show()
matplotlib.pyplot.clf()

# FILTER OUT ONLY THE WANTED DATA =============================================

# NA values that are not more than MAX_NA_CHAIN in a row will be interpolated.
# Otherwise, the entire interval will be discarded.
MAX_NA_CHAIN = 4

# Chosen time window: Wednesdays 6pm to 9pm.
NUM_MINUTES = 3 * 60

df = df[df.index.dayofweek == 2]
df = df[(18 <= df.index.hour) & (df.index.hour < 21)]
# print(df)

# Remove the NA values.
for i in range(0, df.shape[0], NUM_MINUTES):
    df[i: i + NUM_MINUTES] = df[i: i + NUM_MINUTES].interpolate(limit=MAX_NA_CHAIN, limit_direction="both")
    if df[i: i + NUM_MINUTES].isnull().values.any():
        # Mark this entire block as NaN to be removed later.
        df[i: i + NUM_MINUTES] = numpy.nan

df = df.dropna()
# print(df)

# SHUFFLE THE DATA INTERVALS ==================================================
# Pseudo-shuffle used; every third interval is moved to the end.

# But don't actually do this because it's a time series. >:(
# for i in range(0, df.shape[0], NUM_MINUTES):
#     if (i // NUM_MINUTES) % 3 == 1:
#         df = df.append(df[i: i + NUM_MINUTES])
#         df[i: i + NUM_MINUTES] = numpy.nan
# 
# df = df.dropna()

# SAVE THE FILTERED DATAFRAME =================================================

output_list = [",".join(f'"{s}"' for s in df.columns)]
for i, row in df.iterrows():
    output_list.append(",".join(map(str, row)))

with open(OUTPUT_FILE, "w") as fp:
    fp.write("\n".join(output_list))
