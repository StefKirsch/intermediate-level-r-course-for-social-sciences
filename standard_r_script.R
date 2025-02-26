# Load necessary libraries and the create the dataset
library(dplyr)
library(ggplot2)

# create fitness data
source("R/create_synth_data.R")
df_fitness <- create_fitness_data(num_participants = 10, seed = 123)

# view sections of the data
head(df_fitness)

# Use select function to select columns throughout the dataframe.
selected_data_df_fitness <- df_fitness |>
  select(
    study_number,
    Datetime,
    heart_rate
  )

# Use filter function to choose rows based on specific criteria.
filter_snum_df_fitness <- df_fitness |>
  filter(study_number == 2)

# Use filter function to choose rows based on multiple conditions.
## AND condition (& or comma)
filter_and <- df_fitness |>
  filter(study_number == 2  &  heart_rate > 100)

## OR condition (|)
filter_or <- df_fitness |>
  filter(study_number == 2  |  heart_rate > 100)

# Use mutate function to create new columns
mutate_heart_rate <- df_fitness |>
  mutate(above120_avg_hr = heart_rate  > 90)

# Use arrange function to sort data on datetime and on avg heart rate
sorted_data_date_heart_rate_asc <- df_fitness |>
  arrange(Datetime, heart_rate)

# Use arrange function to sort data on datetime and on descending avg heart rate
sorted_data_date_heart_rate_desc <- df_fitness |>
  arrange(Datetime, desc(heart_rate))

# Use groupby and summarise function to arrange each group into a single-row summary of that group.
grouped_data_Datetime_heart_rate <- df_fitness |>
  group_by(day(Datetime)) |>
  summarise(heart_rate_per_day = mean(heart_rate, na.rm = TRUE))

# Use count function to count the number of each different item in a group
count_study_number <- df_fitness |>
  count(study_number)


# Plots

# Plot 1

# Calculate daily average heart rate for each study number
daily_avg_hr_per_study <- df_fitness |>
  mutate(day = as.Date(Datetime)) |>
  group_by(study_number, day) |>
  summarise(avg_daily_heart_rate = mean(heart_rate, na.rm = TRUE), .groups = 'drop')
# Plot
ggplot(daily_avg_hr_per_study, aes(x = day, y = avg_daily_heart_rate, color = as.factor(study_number))) +
  geom_point() +
  geom_line() +
  labs(
    title = "Daily Average Heart Rate for Each Study Number",
    x = "Date",
    y = "Average Heart Rate",
    color = "Study Number"
  ) +
  scale_x_date(date_breaks = "1 day", date_labels = "%b %d") +
  scale_color_hue() +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

#  Calculate the average heart rate over the day for each timestamp and add a "Day" label
hourly_avg_hr <- df_fitness |>
  mutate(
    time_of_day = format(Datetime, "%H:%M"),
    day = as.Date(Datetime),
    day_label = paste("Day", as.integer(day - min(day) + 1))  # Assigns Day 1, Day 2, etc.
  ) |>
  group_by(day, time_of_day, day_label) |>
  summarise(avg_hr_across_studies = mean(heart_rate, na.rm = TRUE), .groups = 'drop')
# Plot
ggplot(hourly_avg_hr, aes(x = as.POSIXct(time_of_day, format = "%H:%M"), y = avg_hr_across_studies, color = factor(day_label, levels = paste("Day", 1:max(as.integer(gsub("Day ", "", hourly_avg_hr$day_label))))))) +
  geom_smooth(se = FALSE, span = 0.3) +  # Using geom_smooth with a smaller span for smoothing

  # comment in and out
  scale_color_hue() +
  theme_minimal() +
  #theme(axis.text.x = element_text(angle = 45, hjust = 1)) +

  # unchanged
  labs(
    title = "Variation of Average Heart Rate Over the Day (Smoothed)",
    x = "Time of Day",
    y = "Average Heart Rate",
    color = "Day"
  ) +
scale_x_datetime(date_breaks = "1 hour", date_labels = "%H:%M")

