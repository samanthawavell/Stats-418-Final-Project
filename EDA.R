# Required packages
library(tidyverse)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)
library(ggplot2)

input_file <- "corvus_cache.rds"
output_file <- "/Users/Sam/Documents/UCLA/STATS_418/Project/CorvusApp/corvus_cache_clean.rds"

corvus_data <- readRDS(input_file)

# Number of total rows before drop_na
nrow(corvus_data)  # Should be 11262 as of 5-5-2025
dim(corvus_data)

# Number of rows after drop_na
corvus_data_dropna <- corvus_data %>%
  drop_na(cnt, season, sp)

nrow(corvus_data_dropna)  # 11252

# Check how many rows had NAs in each relevant column
colSums(is.na(corvus_data[, c("cnt", "season", "sp")])) # 10 observations with missing season

# Save the updated dataset
write_rds(corvus_data_dropna, output_file)

input_file <- "/Users/Sam/Documents/UCLA/STATS_418/Project/CorvusApp/corvus_cache_clean.rds"
corvus_data <- readRDS(input_file)

# View structure and summary
str(corvus_data)
summary(corvus_data)

# View top rows
head(corvus_data)

# Check missing values
colSums(is.na(corvus_data))

# Count by country
table(corvus_data$cnt)
head(sort(table(corvus_data$cnt), decreasing = TRUE), 10)

# Count by species
table(corvus_data$sp)

# Plot seasonal distribution
ggplot(corvus_data, aes(x = season)) +
  geom_bar(fill = "#69b3a2", color = "black", width = 0.7) +
  labs(
    title = "Recording Distribution by Season",
    x = "Season",
    y = "Number of Recordings"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
    axis.title = element_text(face = "bold", size = 13),
    axis.text = element_text(size = 12),
    panel.grid.major.y = element_line(color = "gray85"),
    panel.grid.major.x = element_blank(),
    axis.ticks = element_blank()
  )


# Plot map of recordings by country
# Your country mapping: original → rnaturalearth
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

# Load corvus_data and fix country names
corvus_data$MappedCountry <- country_map[corvus_data$cnt]

# Summarize number of recordings by mapped country
country_counts <- corvus_data %>%
  filter(!is.na(MappedCountry)) %>%
  count(MappedCountry, name = "Recordings")

# Load world map shapefile
world <- ne_countries(scale = "medium", returnclass = "sf")

# Join country counts to map data
world_map <- left_join(world, country_counts, by = c("name" = "MappedCountry"))

# Plot
ggplot(world_map) +
  geom_sf(aes(fill = Recordings), color = "white", size = 0.1) +
  scale_fill_viridis_c(
    na.value = "gray90",
    trans = "log1p",
    option = "viridis",
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
  labs(
    title = "Number of Crow Recordings by Country"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "right",
    legend.title = element_text(face = "bold", size = 12),
    legend.text = element_text(size = 10),
    plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
    panel.grid = element_blank()
  )

