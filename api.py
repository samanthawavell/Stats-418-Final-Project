from flask import Flask, request, jsonify
import joblib
import pandas as pd
import pickle
import os
import requests
import time
import re

app = Flask(__name__)

def download_corvus_data():
    print("Downloading data from xeno-canto API...")

    base_url = "https://xeno-canto.org/api/3/recordings"
    query = "gen:Corvus"
    key = "f8db79ca359b872c557b07d7d91c50674a2e6709"

    # Get total number of pages
    first_url = f"{base_url}?query={query}&page=1&key={key}"
    first_response = requests.get(first_url)
    if first_response.status_code != 200:
        raise Exception(f"Initial request failed: {first_response.status_code}")
    
    first_data = first_response.json()
    num_pages = int(first_data["numPages"])
    print(f"Total pages to fetch: {num_pages}")

    all_records = pd.DataFrame(first_data["recordings"])

    # Loop through remaining pages
    for page_num in range(2, num_pages + 1):
        print(f"Fetching page {page_num} ...")
        time.sleep(0.5)  # Avoid throttling

        url = f"{base_url}?query={query}&page={page_num}&key={key}"
        response = requests.get(url)
        if response.status_code == 200:
            page_data = response.json()
            page_df = pd.DataFrame(page_data["recordings"])
            all_records = pd.concat([all_records, page_df], ignore_index=True)
        else:
            print(f"Warning: Page {page_num} failed with status {response.status_code}")

    # Add season column
    def extract_season(date_str):
        if not isinstance(date_str, str):
            return None
        month_match = re.search(r"-(\d{2})-", date_str)
        if not month_match:
            return None
        month = int(month_match.group(1))
        if month in [1, 2, 3]:
            return "Winter"
        elif month in [4, 5, 6]:
            return "Spring"
        elif month in [7, 8, 9]:
            return "Summer"
        elif month in [10, 11, 12]:
            return "Fall"
        else:
            return None

    all_records["season"] = all_records["date"].apply(extract_season)

    # Filter combinations with at least 10 recordings per country-season
    filtered = (
        all_records.dropna(subset=["cnt", "season"])
        .groupby(["cnt", "season"])
        .filter(lambda x: len(x) >= 10)
    )

    # Save as pickle file
    with open("corvus_cache.pkl", "wb") as f:
        pickle.dump(filtered, f)

    return filtered

def load_or_download_data():
    global data_cache
    if os.path.exists("corvus_cache.pkl"):
        print("Loading cached data...")
        with open("corvus_cache.pkl", "rb") as f:
            data_cache = pickle.load(f)
    else:
        data_cache = download_corvus_data()

# Global variables
model = None
species_lookup = None
data_cache = None
metadata = None

@app.route("/")
def home():
    return "Corvus API is up"

@app.route("/lookup")
def show_lookup():
    return jsonify(species_lookup)

@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json()

    if not data or "cnt" not in data or "season" not in data:
        return jsonify({"error": "Missing 'cnt' or 'season' field"}), 400

    try:
        df_input = pd.DataFrame([data])

        # Load encoders
        df_input["cnt_enc"] = metadata["le_cnt"].transform(df_input["cnt"])
        df_input["season_enc"] = metadata["le_season"].transform(df_input["season"])
        X_input = df_input[["cnt_enc", "season_enc"]]

        # Predict
        probabilities = model.predict_proba(X_input)[0]
        top_indices = probabilities.argsort()[-3:][::-1]
        top_species = [model.classes_[i] for i in top_indices]
        top_probs = [float(probabilities[i]) for i in top_indices]

        return jsonify({
            "top_3_predictions": [
                {"species": species_lookup.get(sp, sp), "probability": prob}
                for sp, prob in zip(top_species, top_probs)
            ]
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/metrics", methods=["GET"])
def get_metrics():
    with open("model_metrics.pkl", "rb") as f:
        metrics = pickle.load(f)

    return jsonify({
        "confusion_matrix": metrics["confusion_matrix"].to_dict(orient="records"),
        "species_stats": metrics["species_stats"].to_dict(orient="records"),
        "accuracy": metrics["accuracy"],
        "ci_lower": metrics["ci_lower"],
        "ci_upper": metrics["ci_upper"],
        "nir": metrics["nir"],
        "p_value": metrics["p_value"],
        "kappa": metrics["kappa"]
    })

@app.route("/metadata", methods=["GET"])
def get_metadata():
    if data_cache is not None:
        return jsonify({"data": data_cache.to_dict(orient="records")})
    else:
        return jsonify({"error": "Metadata not available"}), 500

if __name__ == "__main__":
    # Load or download data
    load_or_download_data()

    print("Loading model...")
    model = joblib.load("rf_model_cached.joblib")

    print("Loading metadata...")
    metadata = joblib.load("rf_model_metadata.joblib")
    species_lookup = metadata.get("species_lookup", {})

    app.run(host="0.0.0.0", port=8080)
