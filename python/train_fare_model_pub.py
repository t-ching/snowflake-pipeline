"""
NYC Taxi Platform: ML Model Training
Trains a Linear Regression model on Silver data to predict fare_amount.
Writes predictions to GOLD.TAXI_PREDICTIONS.
"""

from snowflake.snowpark import Session
import pandas as pd
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score
import json
import os


def get_snowpark_session() -> Session:
    """Create a Snowpark session from environment variables."""
    return Session.builder.configs({
        "account": os.environ["SNOWFLAKE_ACCOUNT"],
        "user": os.environ["SNOWFLAKE_USER"],
        "password": os.environ["SNOWFLAKE_PASSWORD"],
        "role": "SYSADMIN",
        "warehouse": "NYC_TAXI_WH",
        "database": "NYC_TAXI_DB",
        "schema": "SILVER",
    }).create()


def train_fare_prediction_model(session: Session):
    """Train a Linear Regression model to predict fare_amount."""

    print("Loading Silver data...")
    # Sample data to keep training fast
    df_snow = session.table("NYC_TAXI_DB.SILVER.CLEANED_YELLOW_TRIPDATA").sample(n=100000)

    # Select features and target
    feature_cols = [
        "PICKUP_HOUR",
        "PICKUP_DAY_OF_WEEK",
        "TRIP_DISTANCE",
        "PASSENGER_COUNT",
        "TRIP_DURATION_MINUTES",
    ]
    target_col = "FARE_AMOUNT"

    df_pandas = df_snow.select(feature_cols + [target_col]).to_pandas()
    print(f"Training data shape: {df_pandas.shape}")

    # Prepare features and target
    X = df_pandas[feature_cols]
    y = df_pandas[target_col]

    # Train/test split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    # Train Linear Regression
    print("Training Linear Regression model...")
    model = LinearRegression()
    model.fit(X_train, y_train)

    # Evaluate both training and test datasets
    y_train_pred = model.predict(X_train)
    train_mae = mean_absolute_error(y_train, y_train_pred)
    train_r2  = r2_score(y_train, y_train_pred)

    y_test_pred = model.predict(X_test)
    test_mae = mean_absolute_error(y_test, y_test_pred)
    test_r2  = r2_score(y_test, y_test_pred)

    print(f"Model Performance:")
    print(f"  Train (80%):   MAE - {train_mae:.2f} | R² - {train_r2:.4f}")
    print(f"  Test  (20%):   MAE - {test_mae:.2f}  | R² - {test_r2:.4f}")
    print(f"  Coefficients: {dict(zip(feature_cols, model.coef_))}")
    print(f"  Intercept: {model.intercept_:.4f}")

    # Build predictions DataFrame
    predictions_df = pd.DataFrame(X_test)
    predictions_df["ACTUAL_FARE"] = y_test.values
    predictions_df["PREDICTED_FARE"] = y_test_pred.round(2)
    predictions_df["RESIDUAL"] = (predictions_df["ACTUAL_FARE"] - predictions_df["PREDICTED_FARE"]).round(2)

    # Write predictions to Gold table
    print("Writing predictions to GOLD.TAXI_PREDICTIONS...")
    snow_predictions = session.create_dataframe(predictions_df)
    snow_predictions.write.mode("overwrite").save_as_table("NYC_TAXI_DB.GOLD.TAXI_PREDICTIONS")

    # Write model metrics to Gold table
    metrics_df = pd.DataFrame([{
        "MODEL_NAME": "LinearRegression_FarePrediction",
        "MAE": round(test_mae, 4),
        "R2_SCORE": round(test_r2, 4),
        "FEATURES": json.dumps(feature_cols),
        "INTERCEPT": round(model.intercept_, 4),
        "COEFFICIENTS": json.dumps(dict(zip(feature_cols, [round(c, 4) for c in model.coef_]))),
        "TRAINING_ROWS": len(X_train),
        "TEST_ROWS": len(X_test),
    }])
    snow_metrics = session.create_dataframe(metrics_df)
    snow_metrics.write.mode("overwrite").save_as_table("NYC_TAXI_DB.GOLD.MODEL_METRICS")

    print("Done! Predictions written to GOLD.TAXI_PREDICTIONS")
    print(f"Total predictions: {len(predictions_df)}")

    return model, test_mae, test_r2


if __name__ == "__main__":
    session = get_snowpark_session()
    try:
        model, test_mae, test_r2 = train_fare_prediction_model(session)
    finally:
        session.close()
