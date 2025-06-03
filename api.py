from flask import Flask, request, jsonify
import joblib
import pandas as pd
import pickle
import os

app = Flask(__name__)

model = None
species_lookup = None
data_cache = None

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
    # Load cached data
    if os.path.exists("corvus_cache.pkl"):
        print("Loading cached data...")
        with open("corvus_cache.pkl", "rb") as f:
            data_cache = pickle.load(f)

    print("Loading model...")
    model = joblib.load("rf_model_cached.joblib")

    print("Loading metadata...")
    metadata = joblib.load("rf_model_metadata.joblib")
    species_lookup = metadata.get("species_lookup", {})

    app.run(host="0.0.0.0", port=8080)
