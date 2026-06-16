-- ============================================================
-- NYC Taxi Platform: Silver Layer (Cleaned & Enriched)
-- Filters bad records, extracts time features
-- ============================================================

USE DATABASE NYC_TAXI_DB;
USE SCHEMA SILVER;
USE WAREHOUSE NYC_TAXI_WH;

-- Silver table: cleaned trips with extracted features
CREATE OR REPLACE TABLE NYC_TAXI_DB.SILVER.CLEANED_YELLOW_TRIPDATA AS
SELECT
    vendor_id,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    rate_code_id,
    store_and_fwd_flag,
    pu_location_id,
    do_location_id,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    -- Extracted features
    EXTRACT(HOUR FROM tpep_pickup_datetime)      AS pickup_hour,
    EXTRACT(DAYOFWEEK FROM tpep_pickup_datetime) AS pickup_day_of_week,
    DATEDIFF('minute', tpep_pickup_datetime, tpep_dropoff_datetime) AS trip_duration_minutes
FROM NYC_TAXI_DB.BRONZE.RAW_YELLOW_TRIPDATA
WHERE
    -- Filter bad records
    fare_amount > 0
    AND fare_amount < 500
    AND trip_distance > 0
    AND trip_distance < 100
    AND passenger_count > 0
    AND passenger_count <= 6
    AND tpep_pickup_datetime < tpep_dropoff_datetime
    AND DATEDIFF('minute', tpep_pickup_datetime, tpep_dropoff_datetime) BETWEEN 1 AND 240;

SELECT COUNT(*) AS silver_row_count FROM NYC_TAXI_DB.SILVER.CLEANED_YELLOW_TRIPDATA;

-- ============================================================
-- NYC Taxi Platform: Gold Layer (Aggregated Metrics)
-- Business-level summaries for dashboards and reporting
-- ============================================================

USE SCHEMA GOLD;

-- Gold: Hourly trip metrics
CREATE OR REPLACE TABLE NYC_TAXI_DB.GOLD.HOURLY_TRIP_METRICS AS
SELECT
    pickup_hour,
    COUNT(*)                        AS total_trips,
    ROUND(AVG(fare_amount), 2)      AS avg_fare,
    ROUND(AVG(trip_distance), 2)    AS avg_distance,
    ROUND(AVG(tip_amount), 2)       AS avg_tip,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_duration_minutes,
    ROUND(SUM(total_amount), 2)     AS total_revenue
FROM NYC_TAXI_DB.SILVER.CLEANED_YELLOW_TRIPDATA
GROUP BY pickup_hour
ORDER BY pickup_hour;

-- Gold: Daily metrics by day of week
CREATE OR REPLACE TABLE NYC_TAXI_DB.GOLD.DAILY_TRIP_METRICS AS
SELECT
    pickup_day_of_week,
    CASE pickup_day_of_week
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    COUNT(*)                        AS total_trips,
    ROUND(AVG(fare_amount), 2)      AS avg_fare,
    ROUND(AVG(trip_distance), 2)    AS avg_distance,
    ROUND(AVG(total_amount), 2)     AS avg_total_amount,
    ROUND(SUM(total_amount), 2)     AS total_revenue
FROM NYC_TAXI_DB.SILVER.CLEANED_YELLOW_TRIPDATA
GROUP BY pickup_day_of_week
ORDER BY pickup_day_of_week;

-- Gold: Payment type breakdown
CREATE OR REPLACE TABLE NYC_TAXI_DB.GOLD.PAYMENT_TYPE_METRICS AS
SELECT
    payment_type,
    CASE payment_type
        WHEN 1 THEN 'Credit Card'
        WHEN 2 THEN 'Cash'
        WHEN 3 THEN 'No Charge'
        WHEN 4 THEN 'Dispute'
        WHEN 5 THEN 'Unknown'
        WHEN 6 THEN 'Voided'
    END AS payment_type_name,
    COUNT(*)                        AS total_trips,
    ROUND(AVG(fare_amount), 2)      AS avg_fare,
    ROUND(AVG(tip_amount), 2)       AS avg_tip,
    ROUND(SUM(total_amount), 2)     AS total_revenue
FROM NYC_TAXI_DB.SILVER.CLEANED_YELLOW_TRIPDATA
GROUP BY payment_type
ORDER BY total_trips DESC;

SELECT * FROM NYC_TAXI_DB.GOLD.HOURLY_TRIP_METRICS;
