###############################
### STATS 418 FINAL PROJECT ###
####### SAMANTHA WAVELL #######
###############################

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
library(caret)
library(MLmetrics)
library(purrr)

####################
######## UI ########
####################

ui <- fluidPage(
  theme = bs_theme(bootswatch = "pulse"),
  useShinyjs(),
  
  tags$head(
    tags$style(HTML(".banner-img { width: 100%; object-fit: cover; margin-bottom: 20px; }"))
  ),
  
  # Use GitHub raw image URLs
  tags$img(
    src = "https://raw.githubusercontent.com/samanthawavell/Stats-418-Final-Project/main/images/top.png",
    class = "banner-img"
  ),
  
  p(tags$b("How to use this app:"), style = "color: #5A3196"),
  p(HTML("This app pulls data from the public API, xeno-canto.org, on birds of Order: <em>Passeriformes</em>, Family: <em>Corvidae (Crows, Jays)</em>, Genus: <em>Corvus</em>.")),
  p("Predict species using a random forest classification model trained on recordings of crows from the API. The model predicts the most likely crow species based on two inputs: Country and Season of the recording. It uses a 5-fold cross-validation framework to optimize accuracy and outputs the top 3 predicted species along with their predicted probabilities. To ensure performance and reliability, the model is trained once and cached for use throughout the session. A confusion matrix is also displayed to evaluate model performance on the training data. Note that the data are filtered to exclude country/season combinations with less than 10 recordings."),

  p(""),
  p("_________________________________________________________________________________________________________________________________________________________________________________"),

  p(tags$b("Number of Crow Recordings by Country"), style = "color: #5A3196"),
  div(class = "main-panel-space",
      plotlyOutput("recording_map", height = "500px"),
      
  p("_________________________________________________________________________________________________________________________________________________________________________________"),
  p(""),
      
  p(tags$b("Data Table"), style = "color: #5A3196"),
    fluidRow(
      column(12, DTOutput("corvus_table"))
    ),
      
  p("_________________________________________________________________________________________________________________________________________________________________________________"),
  p(""),
  p(tags$b("Predict Species Based on Country and Season of the Recording"), style = "color: #5A3196"),
  p(HTML("First, select a <b>country</b>. Then, select a <b>season</b>. Note that the options for the season will automatically update after a country is selected to display only valid country/season combinations based on the available data. Then, click <b>Predict Species</b> to predict the top 3 species along with their predicted probabilities.")),
  div(class = "controls-panel",
          fluidRow(
            column(4, selectInput("species_predict_country", "Country", choices = c("Select"), selected = "Select")),
            column(4, selectInput("species_predict_season", "Season", choices = c("Select", "Winter", "Spring", "Summer", "Fall"), selected = "Select")),
            column(2, actionButton("predict_species_button", "Predict Species", class = "btn btn-primary")),
            column(2, actionButton("clear_species_button", "Clear Results", class = "btn btn-secondary"))
          ),
          fluidRow(
            column(12, uiOutput("species_prediction_output")),
            p(""),
            p("_________________________________________________________________________________________________________________________________________________________________________________"),
            p(""),
            column(12,
               p(tags$b("Model Accuracy Statistics"), style = "color: #5A3196"),
               p("The model correctly predicted the species 64.4% of the time. The true accuracy of the model is expected to fall between 62.6% and 66.2% with 95% confidence. The model's accuracy is significantly better than random guessing (No Information Rate = 32.7%). Cohen’s Kappa, which adjusts for chance agreement, is 0.55 (moderate). A confusion matrix is displayed below to visualize model performance on the training data."),
               plotOutput("conf_matrix_plot", height = "600px")),
            column(12,
               p("This table summarizes sensitivity and specificity metrics for each species. Sensitivity is the true positive rate, which measures the proportion of actual positives (e.g., recordings of a particular species) that the model correctly identifies. Specificity is the true negative rate, which measures the proportion of actual negatives (recordings not from that species) that the model correctly identifies."),
               DTOutput("species_stats_table"))
            )
      ),
  ),
  
  p(""),
  p("_________________________________________________________________________________________________________________________________________________________________________________"),
  p(""),
  p(tags$b("Data Sources"), style = "color: #5A3196"),
  p("Data retrieved from xeno-canto Application Programming Interface (API v3) (https://xeno-canto.org/explore/api) on June 2, 2025. Crow images are from https://ebird.org/home and https://www.wikipedia.org/."),
  
  div(class = "page-footer", "Copyright 2025, Samantha Wavell"),
  
  p(""),
  
  tags$img(
    src = "https://raw.githubusercontent.com/samanthawavell/Stats-418-Final-Project/main/images/bottom.png",
    class = "banner-img"
  ),
)

####################
###### SERVER ######
####################

server <- function(input, output, session) {  
  
  # Load data via API
  data_rv <- reactiveVal()
  
  observe({
    api_url <- "https://corvus-api-495836339950.us-central1.run.app/metadata"
    response <- tryCatch({
      httr::GET(api_url)
    }, error = function(e) {
      showNotification(paste("Error loading metadata from API:", e$message), type = "error")
      return(NULL)
    })
    
    if (!is.null(response) && httr::status_code(response) == 200) {
      content_data <- content(response, as = "parsed", simplifyVector = TRUE)
      df <- as.data.frame(content_data$data)
      data_rv(df)
      
      updateSelectInput(session, "species_predict_country",
                        choices = sort(unique(df$cnt)),
                        selected = "Select")
    } else {
      showNotification("Failed to load metadata from API.", type = "error")
    }
  })
  
  # Render data table
  output$corvus_table <- renderDT({
    df <- data_rv()
    req(df)
    
    # Add audio player column
    df$audio <- paste0(
      '<audio controls style="width:120px;">',
      '<source src="', df$file, '" type="audio/mpeg">',
      'Your browser does not support the audio element.',
      '</audio>'
    )
    
    # Add clickable URL column
    df$url <- paste0(
      '<a href="', df$url, '" target="_blank">Link</a>'
    )
    
    # Select and rename columns
    desired_cols <- c("id", "sp", "en", "rec", "cnt", "loc",
                      "type", "url", "audio", "length", "date", "season")
    existing_cols <- intersect(desired_cols, names(df))
    df <- df[, existing_cols]
    
    colnames(df) <- c("ID", "Scientific Name", "Common Name", "Recordist", "Country", "Location", 
                      "Type", "URL", "Audio", "Length", "Date", "Season")
    
    # Render datatable
    datatable(
      df,
      escape = FALSE,
      rownames = FALSE,
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        scrollY = "500px",
        dom = 't<"bottom"ip>',
        headerCallback = JS(
          "function(thead, data, start, end, display) {",
          "$('th', thead).css({'background-color': '#5A3196', 'color': 'white'});",
          "}"
        )
      )
    )
  })
  
  observeEvent(input$species_predict_country, {
    req(data_rv())
    df <- data_rv()
    
    valid_seasons <- df %>%
      filter(cnt == input$species_predict_country) %>%
      pull(season) %>%
      unique() %>%
      sort()
    
    updateSelectInput(session, "species_predict_season",
                      choices = valid_seasons,
                      selected = ifelse("Winter" %in% valid_seasons, "Winter", valid_seasons[1]))
  })
  
  observeEvent(input$predict_species_button, {
    req(input$species_predict_country, input$species_predict_season)
    
    request_body <- list(
      cnt = input$species_predict_country,
      season = input$species_predict_season
    )
    
    api_url <- "https://corvus-api-495836339950.us-central1.run.app/predict"
    response <- tryCatch({
      httr::POST(
        url = api_url,
        body = request_body,
        encode = "json",
        httr::add_headers(`Content-Type` = "application/json")
      )
    }, error = function(e) {
      showNotification(paste("Error contacting API:", e$message), type = "error")
      return(NULL)
    })
    
    if (!is.null(response) && httr::status_code(response) == 200) {
      result <- content(response, as = "parsed", simplifyVector = FALSE)
      
      if (!is.null(result$top_3_predictions)) {
        output$species_prediction_output <- renderUI({
          tagList(
            lapply(result$top_3_predictions, function(pred) {
              prob <- pred$probability
              species <- pred$species
              image_filename <- paste0(gsub(" ", "-", species), ".jpeg")
              
              image_url <- paste0(
                "https://raw.githubusercontent.com/samanthawavell/Stats-418-Final-Project/main/images/",
                image_filename
              )
              
              tags$div(
                tags$h4(sprintf("%s: %.1f%%", species, 100 * prob)),
                tags$img(src = image_url, height = "150px")
              )
            })
          )
        })
      } else {
        showNotification("API did not return valid predictions.", type = "error")
      }
    }
  })
  
  # Metrics (confusion matrix, stats)
  observe({
    api_url <- "https://corvus-api-495836339950.us-central1.run.app/metrics"
    response <- tryCatch({
      httr::GET(api_url)
    }, error = function(e) {
      showNotification(paste("Error contacting metrics API:", e$message), type = "error")
      return(NULL)
    })
    
    if (!is.null(response) && httr::status_code(response) == 200) {
      metrics <- content(response, as = "parsed", simplifyVector = TRUE)
      
      output$conf_matrix_plot <- renderPlot({
        cm_df <- as.data.frame(metrics$confusion_matrix)
        
        species_order <- cm_df %>%
          group_by(Reference) %>%
          summarise(Total = sum(Freq)) %>%
          arrange(desc(Total)) %>%
          pull(Reference)
        
        cm_df$Reference <- factor(cm_df$Reference, levels = species_order)
        cm_df$Prediction <- factor(cm_df$Prediction, levels = species_order)
        
        top_species <- head(species_order, 3)
        
        cm_df$text_color <- ifelse(cm_df$Reference == cm_df$Prediction & cm_df$Reference %in% top_species, "black", "white")
        
        ggplot(cm_df, aes(x = Prediction, y = Reference, fill = Freq)) +
          geom_tile(color = "white") +
          geom_text(aes(label = Freq, color = text_color), size = 3, show.legend = FALSE) +
          scale_color_identity() +
          scale_fill_viridis_c(option = "C", trans = "log10") +
          labs(title = "Confusion Matrix", x = "Predicted", y = "Actual") +
          theme_minimal() +
          theme(axis.text.x = element_text(angle = 45, hjust = 1))
      })
      
      output$species_stats_table <- renderDT({
        stats_df <- as.data.frame(metrics$species_stats)
        
        stats_df <- stats_df[, c("Species", "Sensitivity", "Specificity")]
        stats_df <- dplyr::mutate(stats_df, across(c(Sensitivity, Specificity), ~ round(.x, 2)))
        
        datatable(
          stats_df,
          options = list(
            pageLength = 10,
            autoWidth = TRUE,
            scrollX = TRUE,
            dom = 'tip',  # Removes the search bar
            headerCallback = JS(
              "function(thead, data, start, end, display) {",
              "$('th', thead).css({'background-color': '#5A3196', 'color': 'white'});",
              "}"
            )
          ),
          rownames = FALSE
        )
      })
      
      output$model_accuracy_info <- renderUI({
        tagList(
          tags$p(sprintf("Accuracy: %.1f%%", 100 * metrics$accuracy)),
          tags$p(sprintf("95%% CI: %.1f%% – %.1f%%", 100 * metrics$ci_lower, 100 * metrics$ci_upper)),
          tags$p(sprintf("No Information Rate: %.1f%%", 100 * metrics$nir)),
          tags$p(sprintf("p-value: %.3f", metrics$p_value)),
          tags$p(sprintf("Cohen's Kappa: %.2f", metrics$kappa))
        )
      })
    }
  })
  
  observeEvent(input$clear_species_button, {
    output$species_prediction_output <- renderText({ "" })
    updateSelectInput(session, "species_predict_country", selected = "Select")
    updateSelectInput(session, "species_predict_season", selected = "Select")
  })
  
  output$species_prediction_output <- renderUI({ NULL })
  
  # Map
  output$recording_map <- renderPlotly({
    req(data_rv())
    
    df <- data_rv()
    
    # Map country names
    country_map <- c(
      "Andorra" = "Andorra",
      "Armenia" = "Armenia",
      "Australia" = "Australia",
      "Austria" = "Austria",
      "Azerbaijan" = "Azerbaijan",
      "Bahamas" = "The Bahamas",
      "Bangladesh" = "Bangladesh",
      "Belarus" = "Belarus",
      "Belgium" = "Belgium",
      "Benin" = "Benin",
      "Bhutan" = "Bhutan",
      "Bosnia Herzegovina" = "Bosnia and Herzegovina",
      "Bulgaria" = "Bulgaria",
      "Burundi" = "Burundi",
      "Cambodia" = "Cambodia",
      "Cameroon" = "Cameroon",
      "Canada" = "Canada",
      "Cape Verde" = "Cabo Verde",
      "Chad" = "Chad",
      "China" = "China",
      "Congo (Democratic Republic)" = "Democratic Republic of the Congo",
      "Croatia" = "Croatia",
      "Cuba" = "Cuba",
      "Cyprus" = "Cyprus",
      "Czech Republic" = "Czechia",
      "Denmark" = "Denmark",
      "Djibouti" = "Djibouti",
      "Dominican Republic" = "Dominican Republic",
      "Egypt" = "Egypt",
      "Estonia" = "Estonia",
      "Ethiopia" = "Ethiopia",
      "Finland" = "Finland",
      "France" = "France",
      "Gambia" = "Gambia",
      "Georgia" = "Georgia",
      "Germany" = "Germany",
      "Ghana" = "Ghana",
      "Greece" = "Greece",
      "Guatemala" = "Guatemala",
      "Guinea-Bissau" = "Guinea-Bissau",
      "Honduras" = "Honduras",
      "Hungary" = "Hungary",
      "Iceland" = "Iceland",
      "India" = "India",
      "Indonesia" = "Indonesia",
      "Iran" = "Iran",
      "Ireland" = "Ireland",
      "Israel" = "Israel",
      "Italy" = "Italy",
      "Ivory Coast" = "Côte d'Ivoire",
      "Jamaica" = "Jamaica",
      "Japan" = "Japan",
      "Jordan" = "Jordan",
      "Kazakhstan" = "Kazakhstan",
      "Kenya" = "Kenya",
      "Kyrgyzstan" = "Kyrgyzstan",
      "Laos" = "Lao PDR",
      "Latvia" = "Latvia",
      "Lesotho" = "Lesotho",
      "Liechtenstein" = "Liechtenstein",
      "Lithuania" = "Lithuania",
      "Luxembourg" = "Luxembourg",
      "Madagascar" = "Madagascar",
      "Malawi" = "Malawi",
      "Malaysia" = "Malaysia",
      "Maldives" = "Maldives",
      "Mali" = "Mali",
      "Mauritius" = "Mauritius",
      "Mexico" = "Mexico",
      "Mongolia" = "Mongolia",
      "Morocco" = "Morocco",
      "Mozambique" = "Mozambique",
      "Myanmar" = "Myanmar",
      "Namibia" = "Namibia",
      "Nepal" = "Nepal",
      "Netherlands" = "Netherlands",
      "Nicaragua" = "Nicaragua",
      "Nigeria" = "Nigeria",
      "Norway" = "Norway",
      "Oman" = "Oman",
      "Pakistan" = "Pakistan",
      "Papua New Guinea" = "Papua New Guinea",
      "Philippines" = "Philippines",
      "Poland" = "Poland",
      "Portugal" = "Portugal",
      "Romania" = "Romania",
      "Russian Federation" = "Russia",
      "Rwanda" = "Rwanda",
      "Saudi Arabia" = "Saudi Arabia",
      "Senegal" = "Senegal",
      "Serbia" = "Serbia",
      "Sierra Leone" = "Sierra Leone",
      "Singapore" = "Singapore",
      "Slovakia" = "Slovakia",
      "Slovenia" = "Slovenia",
      "Solomon Islands" = "Solomon Islands",
      "Somalia" = "Somalia",
      "South Africa" = "South Africa",
      "South Korea" = "South Korea",
      "Spain" = "Spain",
      "Sri Lanka" = "Sri Lanka",
      "Sweden" = "Sweden",
      "Switzerland" = "Switzerland",
      "Taiwan" = "Taiwan",
      "Tanzania" = "Tanzania",
      "Thailand" = "Thailand",
      "Tunisia" = "Tunisia",
      "Turkey" = "Turkey",
      "Uganda" = "Uganda",
      "Ukraine" = "Ukraine",
      "United Arab Emirates" = "United Arab Emirates",
      "United Kingdom" = "United Kingdom",
      "United States" = "United States of America",
      "Uzbekistan" = "Uzbekistan",
      "Vietnam" = "Vietnam",
      "Zambia" = "Zambia",
      "Zimbabwe" = "Zimbabwe"
    )
    
    df$MappedCountry <- country_map[df$cnt]
  
  country_counts <- df %>%
    filter(!is.na(MappedCountry)) %>%
    count(MappedCountry, name = "Recordings")
  
  world <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf")
  world_map <- left_join(world, country_counts, by = c("name" = "MappedCountry"))
  
  # Tooltip
  world_map$tooltip <- ifelse(
    is.na(world_map$Recordings),
    paste0(world_map$name, ": No data"),
    paste0(world_map$name, ": ", world_map$Recordings, " recordings")
  )
  
  gg <- ggplot(world_map) +
    geom_sf(aes(fill = Recordings, text = tooltip), color = "white", size = 0.1) +
    scale_fill_viridis_c(
      na.value = "gray90",
      trans = "log1p",
      option = "plasma",
      name = "Recordings",
      guide = guide_colorbar(
        barwidth = unit(0.4, "cm"),
        barheight = unit(5, "cm"),
        title.position = "top",
        title.hjust = 0.5,
        label.theme = element_text(size = 9),
        ticks.colour = "black"
      )
    ) +
    theme_minimal(base_size = 14) +
    theme(
      legend.position = "right",
      legend.title = element_text(face = "bold", size = 12),
      legend.text = element_text(size = 8),
      plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
      panel.grid = element_blank()
    )
  
  ggplotly(gg, tooltip = "text") %>%
    layout(
      margin = list(l = 0, r = 0, b = 0, t = 40),
      xaxis = list(title = NULL, showticklabels = FALSE, zeroline = FALSE),
      yaxis = list(title = NULL, showticklabels = FALSE, zeroline = FALSE)
    )
})
  
}

shinyApp(ui, server)
