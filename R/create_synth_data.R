# Load necessary libraries
library(dplyr)
library(lubridate)
library(haven)
library(labelled)

#' Generate Synthetic Fitness Tracker Data with a Defined Linear Trend
#'
#' This function generates a synthetic dataset of fitness tracker data for multiple participants over two weeks.
#' Each participant has a linear trend starting from 0 and ending between -10 and +10, with random heart rate values
#' added to this baseline trend.
#' Days that are in weeks with less than 4 compliant week days have a higher heart rate, too.
#'
#' @param num_participants Integer. Number of participants to generate data for (default is 1).
#' @param seed Integer. Seed for random number generation (default is 42).
#' @return A data frame with synthetic fitness tracker data for all participants.
#' @examples
#' df <- create_fitness_data(num_participants = 10)
#' head(df)
#' @importFrom dplyr bind_rows
#' @importFrom lubridate ymd_hms minutes
#' @export
create_fitness_data <- function(num_participants = 1, seed = 123) {
  # Set seed for reproducibility
  set.seed(seed)

  # Initialize list to hold data for all participants
  participant_list <- vector("list", num_participants)

  # Loop over participants
  for (p in seq_len(num_participants)) {
    study_number <- p

    # Define a random endpoint for the trend line between -10 and +10
    trend_end <- runif(1, -20, 20)

    # Define the time range for each day (from noon to 2 pm)
    time_start <- ymd_hms("2021-01-01 12:00:00")
    time_end <- ymd_hms("2021-01-01 14:00:00") - minutes(1)

    # Generate a sequence of times at minute intervals for one day
    times_one_day <- seq(from = time_start, to = time_end, by = "1 min")
    num_time_points <- length(times_one_day)  # Should be 120 minutes

    # Number of days (14 days for 2 weeks)
    num_days <- 14

    # Generate dates for two weeks
    dates <- seq.Date(from = as.Date("2021-01-01"), by = "day", length.out = num_days)

    # Generate week_id for each date
    week_id <- rep(1:2, each = 7)

    # Create a linear trend from 0 to trend_end over the full period (14 days * 120 time points)
    trend_line <- seq(0, trend_end, length.out = num_days * num_time_points)

    # Initialize an empty list to store daily data frames
    df_list <- vector("list", num_days)

    for (i in seq_len(num_days)) {
      # Current date and week_id
      current_date <- dates[i]
      current_week_id <- week_id[i]

      # Generate datetime stamps for the current day
      datetimes <- as.POSIXct(paste(current_date, format(times_one_day, "%H:%M:%S")))

      # Introduce missing data in continuous blocks
      missing_indices <- integer(0)

      # Randomly decide the number of missing blocks (1 or 2 per day)
      num_blocks <- sample(1:2, 1)

      for (b in seq_len(num_blocks)) {
        # Randomly select duration between 10 and 70 minutes
        duration <- sample(10:60, 1)

        # Ensure the start index allows the full duration within the day's time points
        max_start_index <- num_time_points - duration + 1
        if (max_start_index < 1) break  # Skip if not enough time points left

        # Randomly select start index
        start_index <- sample(1:max_start_index, 1)
        end_index <- start_index + duration - 1

        # Append indices to missing_indices
        indices <- start_index:end_index
        missing_indices <- c(missing_indices, indices)
      }

      # Ensure missing_indices are unique and within the time range
      missing_indices <- unique(missing_indices[missing_indices <= num_time_points])

      # Observed indices are those not in missing_indices
      observed_indices <- setdiff(seq_len(num_time_points), missing_indices)

      # Initialize heart_rate with NA
      heart_rate <- rep(NA, num_time_points)

      # Get the relevant portion of the trend line for this day
      trend_for_day <- trend_line[((i - 1) * num_time_points + 1):(i * num_time_points)]

      # Simulate heart_rate for observed indices, adding the trend line to random fluctuations
      heart_rate[observed_indices] <- round(
        70 + trend_for_day[observed_indices] + rnorm(length(observed_indices), mean = 0, sd = 10), 1
      )

      # Determine is_compliant_day
      is_compliant_day <- length(observed_indices) >= num_time_points / 2

      # Create a data frame for the current day
      df_day <- data.frame(
        study_number = study_number,
        Datetime = datetimes,
        week_id = current_week_id,
        is_compliant_day = is_compliant_day,
        heart_rate = heart_rate
      )

      # Append to the list
      df_list[[i]] <- df_day
    }

    # Combine all days into one data frame for this participant
    df_participant <- bind_rows(df_list)

    # Append participant data to participant_list
    participant_list[[p]] <- df_participant
  }

  # Combine data for all participants
  df_all <- bind_rows(participant_list)

  # Begin adding helper columns
  df_all <- df_all |>
    mutate(
      # Helper columns
      day_h = as.Date(Datetime),
      weekday_h = wday(Datetime, week_start = "Monday"),
      is_weekday_h = weekday_h %in% c(1, 2, 3, 4, 5),
      is_compliant_weekday_h = is_weekday_h & is_compliant_day
    )

  # Calculate the number of compliant weekdays per week per participant
  df_weekly <- df_all |>
    group_by(study_number, week_id) |>
    summarise(
      n_compliant_weekday_h = n_distinct(day_h[is_compliant_weekday_h]),
      is_compliant_week_h = n_compliant_weekday_h >= 4,
      .groups = 'drop'
    )

  # Merge weekly compliance back into the main dataframe
  df_all <- df_all |>
    left_join(df_weekly, by = c("study_number", "week_id"))

  # Adjust heart_rate by adding 2 for non-compliant weeks
  df_all <- df_all |>
    mutate(
      intervention = ifelse(week_id == 2, TRUE, FALSE),
      .after = week_id
    ) |>
    mutate(
      heart_rate = round(ifelse(!is_compliant_week_h & !is.na(heart_rate),
                              heart_rate + 30,
                              heart_rate))
    )

  # Remove helper columns ending with '_h'
  df_all <- df_all |>
    select(-ends_with("_h"))

  return(df_all)
}


create_large_dataset <- function(n = 1e5, seed = 123) {
  # Generate a large sample dataset
  df <- data.frame(
    id = sample(1:1000, n, replace = TRUE),
    x = rnorm(n),
    y = runif(n),
    z = rpois(n, lambda = 5),
    group = sample(letters, n, replace = TRUE)
  )

  return(df)
}


create_survey_data <- function(n = 1e4, seed = 123) {
  set.seed(seed) # Set seed for reproducibility

  df <- tibble(
    # Age between 18 and 65
    age = labelled(
      sample(18:65, n, replace = TRUE),
      label = "What is your age?"
    ),

    # Gender: Male or Female
    gender = labelled(
      sample(c(1, 2), n, replace = TRUE),
      labels = c("Male" = 1, "Female" = 2),
      label = "What is your gender?"
    ) |> as_factor(),

    # Education: High School, Bachelor's, Master's
    education = labelled(
      sample(c(1, 2, 3), n, replace = TRUE),
      labels = c(
        "High School" = 1,
        "Bachelor's" = 2,
        "Master's" = 3
      ),
      label = "What is your highest level of education completed?"
    ) |>
      as_factor(ordered = TRUE),

    # Job Satisfaction
    job_satisfaction = labelled(
      sample(1:5, n, replace = TRUE),
      labels = c(
        "Fully Disagree" = 1,
        "Disagree" = 2,
        "Neutral" = 3,
        "Agree" = 4,
        "Fully Agree" = 5
      ),
      label = "I am satisfied with my current job."
    ) |>
      as_factor(ordered = TRUE),

    # Mental Health
    mental_health = labelled(
      sample(1:5, n, replace = TRUE),
      labels = c(
        "Fully Disagree" = 1,
        "Disagree" = 2,
        "Neutral" = 3,
        "Agree" = 4,
        "Fully Agree" = 5
      ),
      label = "I feel mentally healthy at work."
    ) |>
      as_factor(ordered = TRUE),

    # Placeholder for stress_at_job
    stress_at_job = labelled(
      NA_integer_,
      label = "I often feel stressed because of my job."
    ),

    # Years of experience as a continuous variable
    years_experience = labelled(
      pmax(0, age - 18) * runif(n, min = 0.3, max = 1), # Range from 0 up to age - 18
      label = "How many years of experience do you have?"
    ),

    # Continuous salary variable influenced by education, gender, age, and years_experience
    salary = labelled(
      rnorm(n, mean = 40000 + age * 800 + years_experience * 1200 +
              ifelse(education == "Master's", 20000, ifelse(education == "Bachelor's", 10000, 0)) +
              ifelse(gender == "Male", 5000, 0), sd = 5000),
      label = "What is your annual salary?"
    )
  )

  # Introduce trends in stress_at_job
  df <- df |>
    mutate(
      # Base stress level decreases slightly with age
      stress_score = 3 - (age - mean(age)) * 0.02,

      # Apply first bump: Lower stress for High School education between 40 and 50
      stress_score = stress_score + if_else(
        education == "High School" & age >= 40 & age <= 50,
        -0.3,
        0
      ),

      # Apply second bump: Higher stress for Master's females between 25 and 35
      stress_score = stress_score + if_else(
        gender == "Female" & education == "Master's" & age >= 25 & age <= 35,
        0.3,
        0
      ),

      # Add random noise
      stress_score = stress_score + rnorm(n(), mean = 0, sd = 0.5),

      # Ensure stress_score is within 1 to 5
      stress_score = pmin(pmax(stress_score, 1), 5),

      # Convert to ordered factor with labels using as_factor()
      stress_at_job = labelled(
        as.integer(round(stress_score)),
        labels = c(
          "Fully Disagree" = 1,
          "Disagree" = 2,
          "Neutral" = 3,
          "Agree" = 4,
          "Fully Agree" = 5
        ),
        label = attr(df$stress_at_job, "label")
      ) |> as_factor(ordered = TRUE)
    ) |>
    select(-stress_score) # Remove temporary variable

  return(df)
}
