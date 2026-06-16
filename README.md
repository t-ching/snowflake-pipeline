# A Native Snowflake Project on Data Engineering and ML Model.

Utilise the pubicly available New York City Taxi & Limousine Commission (TLC) trip data to built a data pipeline with ML fare prediction and a Streamlit dashboard.

## Architecture

```
Azure Open Data (NYC TLC Parquet)
        |
        v
  [Bronze Layer]  -- Raw ingestion via external stage + COPY INTO
        |
        v
  [Silver Layer]  -- Data quality filters + feature extraction
        |
        v
  [Gold Layer]    -- Aggregated metrics (hourly, daily, payment type)
        |
        v
  [ML Model]      -- Linear Regression fare prediction (scikit-learn)
        |
        v
  [Streamlit]     -- Interactive dashboard with KPIs and charts
```

## Dataset

- **Source:** [Azure Open Datasets - NYC TLC Yellow Taxi](https://learn.microsoft.com/en-us/azure/open-datasets/dataset-taxi-yellow)
- **Volume:** ~44M trips (year 2019 only)
- **Format:** Parquet, Hive-partitioned by `puYear` / `puMonth`

## Project Structure

```
.
├── sql/
│   ├── 01_setup_infrastructure.sql         # Database, schemas, warehouse
│   ├── 02_bronze_ingestion.sql             # External stage + COPY INTO
│   └── 03_silver_gold_transformations.sql  # Silver cleaning + Gold aggregations
├── python/
│   └── train_fare_model_pub.py             # ML training + writes to Gold
├── streamlit/
│   └── app_pub.py                          # Dashboard (4 tabs)
├── requirements.txt
├── .env.example
└── .gitignore
```

## Setup

### Prerequisites

- Snowflake account with `SYSADMIN` role access
- Python 3.10+
- pip

### 1. Install dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure credentials

```bash
cp .env.example .env
# Edit .env with your Snowflake account, user, and password
```

Then load them:

```bash
export $(cat .env | xargs)
```

### 3. Run SQL scripts (in order)

Execute in Snowsight or any SQL client:

1. `sql/01_setup_infrastructure.sql` -- creates database, schemas, warehouse
2. `sql/02_bronze_ingestion.sql` -- loads raw Parquet from Azure into Bronze
3. `sql/03_silver_gold_transformations.sql` -- builds Silver and Gold tables

### 4. Train the ML model

```bash
python python/train_fare_model_pub.py
```

This trains a Linear Regression model on Silver data and writes predictions + metrics to the Gold layer.

### 5. Launch the dashboard

```bash
streamlit run streamlit/app_pub.py
```

## Dashboard Tabs

| Tab | Description |
|-----|-------------|
| Hourly Metrics | Trip volume and avg fare/tip by hour of day |
| Daily Metrics | Trip volume and revenue by day of week |
| Payment Breakdown | Credit card vs cash vs other payment types |
| ML Predictions | Model accuracy (MAE, R2) + actual vs predicted scatter plot |

## Row Counts

| Layer | Table | Rows |
|-------|-------|------|
| Bronze | `RAW_YELLOW_TRIPDATA` | ~44.5M |
| Silver | `CLEANED_YELLOW_TRIPDATA` | ~43.1M |
| Gold | `HOURLY_TRIP_METRICS` | 24 |
| Gold | `DAILY_TRIP_METRICS` | 7 |
| Gold | `PAYMENT_TYPE_METRICS` | 4 |

The Silver layer filters ~3% of records with invalid fares, distances, or durations.

## Technologies

- **Snowflake** -- warehouse, external stages, COPY INTO
- **Snowpark Python** -- DataFrame API for ML pipeline
- **scikit-learn** -- Linear Regression model
- **Streamlit** -- interactive dashboard
- **Azure Open Data** -- public NYC taxi dataset (Parquet)
