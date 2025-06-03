# STATS 418 Final Project

This repository contains the source code and assets for a machine learning-powered Shiny app built for the STATS 418 final project.

The project predicts the species of crow from which a bird recording originates, based on location (country) and season (fall, winter, spring, summer) of the recording. A random forest classifier was trained on metadata from the [xeno-canto](https://xeno-canto.org) bird sound database. The app displays species predictions along with audio recordings, model performance metrics, and an interactive data table.

Access the live Shiny app here:  
👉 [https://96upvf-samantha-wavell.shinyapps.io/Stats-418-Final-Project-App/](https://96upvf-samantha-wavell.shinyapps.io/Stats-418-Final-Project-App/)

---

## 📁 Repository Structure

| File / Folder | Description |
|---------------|-------------|
| `images/` | Folder containing all crow species images and banner images used in the Shiny app (referenced in `app_R.R`). |
| `Dockerfile` | Docker configuration to containerize the API used by the Shiny app. |
| `Stats418_ProjectProposal_SamanthaWavell.pdf` | Project proposal slides submitted earlier in the quarter. |
| `Stats418_ProjectSlides_SamanthaWavell.pdf` | Final presentation slides summarizing the app, model, and results. |
| `api.py` | Flask-based REST API that serves the trained model’s predictions and metrics. |
| `app_R.R` | The main R Shiny app script that loads data, interacts with the API, and displays outputs. |
| `requirements.txt` | Python dependencies required for building and running the API. |
| `rf_model_training.py` | Python script that trains the random forest model, encodes data, evaluates performance, and caches results. |

---

## 🛠 How It Works

1. **Model Training (`rf_model_training.py`)**
   - Trains a random forest classifier on crow species recordings.
   - Encodes categorical variables and computes performance metrics.
   - Saves model and metadata for API use.

2. **API (`api.py`)**
   - A Flask web server that returns species predictions and model performance statistics.
   - Can be containerized using the included Dockerfile and deployed to Google Cloud Run.

3. **Shiny App (`app_R.R`)**
   - A front-end interface that lets users select a country and season.
   - Displays the top 3 predicted species (with images), model statistics, a confusion matrix, and an interactive map and data table.
   - Loads prediction results from the deployed API.

---

© 2025 Samantha Wavell
