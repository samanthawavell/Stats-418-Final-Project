library(shiny)
library(httr)
library(jsonlite)
library(dplyr)
library(DT)
library(stringr)
library(leaflet)
library(bslib)
library(shinyjs)
library(tidyr)
library(rnaturalearth)
library(rnaturalearthdata)
library(ggplot2)
library(sf)
library(viridis)
library(plotly)
library(xgboost)
library(caret)
library(MLmetrics)
library(purrr)

####################
##### THE DATA #####
####################

# Function to download data from xeno-canto for Corvus
download_corvus_data <- function() {
  message("Downloading data from xeno-canto API...")
  
  # Define the base URL and query parameters
  base_url <- "https://xeno-canto.org/api/3/recordings"
  query <- "gen:Corvus"
  key <- "f8db79ca359b872c557b07d7d91c50674a2e6709"
  
  # Fetch first page to get numPages
  first_url <- paste0(base_url, "?query=", query, "&page=1&key=", key)
  first_response <- httr::GET(first_url)
  
  if (first_response$status_code != 200) {
    stop("Initial API request failed with status code ", first_response$status_code)
  }
  
  first_data <- content(first_response, as = "parsed", simplifyDataFrame = TRUE)
  num_pages <- as.integer(first_data$numPages)
  message("Total pages to fetch: ", num_pages)
  
  # Initialize list and add first page of recordings
  all_recordings <- list(first_data$recordings)
  
  # Loop through remaining pages
  for (page_num in 2:num_pages) {
    message("Fetching page ", page_num, " ...")
    
    # Add delay to avoid throttling
    Sys.sleep(0.5)
    
    url <- paste0(base_url, "?query=", query, "&page=", page_num, "&key=", key)
    response <- httr::GET(url)
    
    if (response$status_code == 200) {
      data <- content(response, as = "parsed", simplifyDataFrame = TRUE)
      all_recordings <- append(all_recordings, list(data$recordings))
    } else {
      warning("Page ", page_num, " failed with status code ", response$status_code)
    }
  }
  
  # Combine into a single data frame
  all_recordings_df <- dplyr::bind_rows(lapply(all_recordings, function(x) {
    as.data.frame(x, stringsAsFactors = FALSE)
  }))
  
  # Add the season column
  all_recordings_df$season <- dplyr::case_when(
    stringr::str_detect(all_recordings_df$date, "-01") | stringr::str_detect(all_recordings_df$date, "-02") | stringr::str_detect(all_recordings_df$date, "-03") ~ "Winter",
    stringr::str_detect(all_recordings_df$date, "-04") | stringr::str_detect(all_recordings_df$date, "-05") | stringr::str_detect(all_recordings_df$date, "-06") ~ "Spring",
    stringr::str_detect(all_recordings_df$date, "-07") | stringr::str_detect(all_recordings_df$date, "-08") | stringr::str_detect(all_recordings_df$date, "-09") ~ "Summer",
    stringr::str_detect(all_recordings_df$date, "-10") | stringr::str_detect(all_recordings_df$date, "-11") | stringr::str_detect(all_recordings_df$date, "-12") ~ "Fall",
    TRUE ~ NA_character_
  )
  
  # Remove combinations with < 10 recordings per season
  ten_df <- all_recordings_df %>%
    filter(!is.na(cnt), !is.na(season)) %>%
    group_by(cnt, season) %>%
    filter(n() >= 10) %>%
    ungroup()
  
  # Save
  saveRDS(ten_df, "corvus_cache.rds")
  
  return(ten_df)
}

# Load or download data
data_rv <- reactiveVal()
if (file.exists("corvus_cache.rds")) {
  message("Loading cached data...")
  data_rv(readRDS("corvus_cache.rds"))
} else {
  data_rv(download_corvus_data())
}
