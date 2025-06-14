# Stats 418 Final Project

This repository contains the source code and assets for an API-powered Shiny app built for the Stats 418 final project.

The app predicts the species of crow from which a bird recording originates, based on location (country) and season (fall, winter, spring, summer) of the recording. A random forest classifier was trained on metadata from the [xeno-canto](https://xeno-canto.org) bird sound database. The app displays species predictions along with audio recordings, model performance metrics, and an interactive data table. Note that the app may take up to a minute to fully load.

Access the live Shiny app here:  
[https://96upvf-samantha-wavell.shinyapps.io/Stats-418-Final-Project-App/](https://96upvf-samantha-wavell.shinyapps.io/Stats-418-Final-Project-App/)

---

## Repository Structure

| File / Folder | Description |
|---------------|-------------|
| `images/` | Folder containing all crow species images and banner images used in the Shiny app (referenced in `app_R.R`). |
| `Dockerfile` | Docker configuration to containerize the API used by the Shiny app. |
| `Stats418_ProjectProposal_SamanthaWavell.pdf` | Project proposal slides submitted earlier in the quarter. |
| `Stats418_ProjectSlides_SamanthaWavell.pdf` | Final presentation slides summarizing the app, model, and results. |
| `Stats_418_Final_Project_Writeup.pdf` | Final project writeup detailing exploratory data analysis, methodology, and results. |
| `api.py` | Flask-based REST API that serves the trained model’s predictions and metrics. |
| `app_R.R` | The main R Shiny app script that loads data, interacts with the API, and displays outputs. |
| `corvus_cache.pkl` | File containing a cleaned and preprocessed dataset of crow audio recordings data downloaded from the xeno-canto API. |
| `requirements.txt` | Python dependencies required for building and running the API. |
| `rf_model_training.py` | Python script that trains the random forest model, encodes data, evaluates performance, and caches results. |

---

## How It Works

1. **Model Training (`rf_model_training.py`)**
   - Uses the `corvus_cache.pkl` data to train a random forest classifier on crow species recordings.
   - Encodes categorical variables and computes performance metrics.
   - Saves model and metadata for API use.

2. **API (`api.py`)**
   - A Flask web server that returns species predictions and model performance statistics.
   - On startup, the script checks for the presence of `corvus_cache.pkl`. If it does not exist, the API automatically downloads the data from the xeno-canto API, extracts metadata, adds a seasonal label based on the recording date, filters by country-season combinations with sufficient recordings, and saves the resulting dataset to `corvus_cache.pkl`.
   - Can be containerized using the included Dockerfile and deployed to Google Cloud Run.

3. **Shiny App (`app_R.R`)**
   - A front-end interface that lets users select a country and season.
   - Displays the top 3 predicted species (with images), model statistics, a confusion matrix, and an interactive map and data table.
   - Loads prediction results from the deployed API.

---

## API Access & Examples

The API is deployed on **Google Cloud Run** and can be accessed directly using tools like `curl` or programmatically from any language that supports HTTP.

### Check if API is running
```curl https://corvus-api-495836339950.us-central1.run.app/```

Response: "Corvus API is up"

### Predict species
You must POST a JSON payload with "cnt" (country) and "season" values.

#### Example: Predict for Canada in Winter:
```bash
curl -X POST https://corvus-api-495836339950.us-central1.run.app/predict \
  -H "Content-Type: application/json" \
  -d '{"cnt": "Canada", "season": "Winter"}'
```
Response: "{"top_3_predictions":[{"probability":0.5170714740986264,"species":"Northern Raven"},{"probability":0.4829285259013736,"species":"American Crow"},{"probability":0.0,"species":"Hispaniolan Palm Crow"}]}"

#### Example: Predict for India in Summer:
```bash
curl -X POST https://corvus-api-495836339950.us-central1.run.app/predict \
  -H "Content-Type: application/json" \
  -d '{"cnt": "India", "season": "Summer"}'
```
Response: "{"top_3_predictions":[{"probability":0.4874270753584224,"species":"House Crow"},{"probability":0.21222693036237952,"species":"Large-billed Crow"},{"probability":0.20004049252261363,"species":"Indian Jungle Crow"}]}"

### Get all model metrics
```bash
curl https://corvus-api-495836339950.us-central1.run.app/metrics
```

---

© 2025 Samantha Wavell
