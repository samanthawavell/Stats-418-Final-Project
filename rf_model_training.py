import joblib
import pandas as pd
import numpy as np
import pickle
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    confusion_matrix,
    classification_report,
    cohen_kappa_score,
    accuracy_score
)
from statsmodels.stats.proportion import proportion_confint

# Load training data
df = pd.read_pickle("corvus_cache.pkl")

# Drop missing values
df = df.dropna(subset=["cnt", "season", "en"])

# Label encode categorical features
le_species = LabelEncoder()
le_cnt = LabelEncoder()
le_season = LabelEncoder()

df["species_enc"] = le_species.fit_transform(df["en"])
df["cnt_enc"] = le_cnt.fit_transform(df["cnt"])
df["season_enc"] = le_season.fit_transform(df["season"])

# Remove rare species (< 10 observations)
species_counts = df["species_enc"].value_counts()
valid_species = species_counts[species_counts >= 10].index
df = df[df["species_enc"].isin(valid_species)]

# Define X and y
X = df[["cnt_enc", "season_enc"]]
y = df["species_enc"]

# Train/test split
X_train, X_test, y_train, y_test = train_test_split(X, y, stratify=y, random_state=42)

# Train Random Forest
model = RandomForestClassifier(n_estimators=500, random_state=123)
model.fit(X_train, y_train)

# Save trained model
joblib.dump(model, "rf_model_cached.joblib")

# Predict on test set
y_pred = model.predict(X_test)

# Evaluation
report = classification_report(y_test, y_pred, zero_division=0, output_dict=True)
conf_matrix = confusion_matrix(y_test, y_pred)
accuracy = accuracy_score(y_test, y_pred)
kappa = cohen_kappa_score(y_test, y_pred)
nir = y_test.value_counts(normalize=True).max()
p_value = 1 if accuracy <= nir else 0.0
ci_low, ci_high = proportion_confint(count=accuracy * len(y_test), nobs=len(y_test), method="wilson")

# Build species lookup
species_lookup = dict(zip(range(len(le_species.classes_)), le_species.classes_))

# Confusion matrix
conf_df = pd.DataFrame(conf_matrix,
                       index=le_species.inverse_transform(sorted(valid_species)),
                       columns=le_species.inverse_transform(sorted(valid_species)))
conf_df = conf_df.reset_index().melt(id_vars="index", var_name="Prediction", value_name="Freq")
conf_df.rename(columns={"index": "Reference"}, inplace=True)

from sklearn.metrics import multilabel_confusion_matrix

# Per-species stats
report_df = pd.DataFrame(report).T
str_labels = [str(label) for label in sorted(valid_species)]
species_stats = report_df.loc[str_labels, ["recall"]].copy()
species_stats.index = le_species.inverse_transform([int(i) for i in species_stats.index])
species_stats.index.name = "Species"
species_stats.rename(columns={"recall": "Sensitivity"}, inplace=True)
species_stats = species_stats.reset_index()

# Compute Specificity
cm_list = multilabel_confusion_matrix(y_test, y_pred, labels=sorted(valid_species))
specificities = []

for i, cm in enumerate(cm_list):
    tn, fp, fn, tp = cm.ravel()
    specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
    specificities.append(specificity)

species_stats["Specificity"] = specificities

# Save metrics in a separate pkl file
metrics_dict = {
    "confusion_matrix": conf_df,
    "species_stats": species_stats,
    "accuracy": accuracy,
    "ci_lower": ci_low,
    "ci_upper": ci_high,
    "nir": nir,
    "p_value": p_value,
    "kappa": kappa
}
with open("model_metrics.pkl", "wb") as f:
    pickle.dump(metrics_dict, f)

# Save metadata
joblib.dump({
    "le_species": le_species,
    "le_cnt": le_cnt,
    "le_season": le_season,
    "species_lookup": species_lookup,
    "classification_report": report,
    "confusion_matrix": conf_df,
    "species_stats": species_stats,
    "accuracy": accuracy,
    "ci_lower": ci_low,
    "ci_upper": ci_high,
    "nir": nir,
    "p_value": p_value,
    "kappa": kappa
}, "rf_model_metadata.joblib")
