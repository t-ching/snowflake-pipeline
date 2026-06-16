-- ============================================================
-- NYC Taxi Platform: Bronze Layer Ingestion
-- External stage + raw Parquet load into Bronze table
-- ============================================================

USE DATABASE NYC_TAXI_DB;
USE SCHEMA BRONZE;
USE WAREHOUSE NYC_TAXI_WH;

-- Create file format for Parquet ingestion
CREATE OR REPLACE FILE FORMAT NYC_TAXI_DB.BRONZE.PARQUET_FF
    TYPE = PARQUET;

-- Create external stage pointing to Azure Open Data NYC TLC yellow taxi
CREATE OR REPLACE STAGE NYC_TAXI_DB.BRONZE.NYC_TLC_STAGE
    URL = 'azure://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/'
    FILE_FORMAT = NYC_TAXI_DB.BRONZE.PARQUET_FF;

-- List files for January 2019 to verify connectivity
LIST @NYC_TAXI_DB.BRONZE.NYC_TLC_STAGE PATTERN = '.*puYear=2019/puMonth=1/.*\.parquet';

-- Create raw Bronze table matching the Parquet schema
CREATE OR REPLACE TABLE NYC_TAXI_DB.BRONZE.RAW_YELLOW_TRIPDATA (
    vendor_id               NUMBER,
    tpep_pickup_datetime    TIMESTAMP_NTZ,
    tpep_dropoff_datetime   TIMESTAMP_NTZ,
    passenger_count         NUMBER,
    trip_distance           FLOAT,
    rate_code_id            NUMBER,
    store_and_fwd_flag      VARCHAR,
    pu_location_id          NUMBER,
    do_location_id          NUMBER,
    payment_type            NUMBER,
    fare_amount             FLOAT,
    extra                   FLOAT,
    mta_tax                 FLOAT,
    tip_amount              FLOAT,
    tolls_amount            FLOAT,
    improvement_surcharge   FLOAT,
    total_amount            FLOAT,
    load_timestamp          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Load January 2019 data from Parquet into the Bronze table
COPY INTO NYC_TAXI_DB.BRONZE.RAW_YELLOW_TRIPDATA (
    vendor_id, tpep_pickup_datetime, tpep_dropoff_datetime,
    passenger_count, trip_distance, rate_code_id, store_and_fwd_flag,
    pu_location_id, do_location_id, payment_type,
    fare_amount, extra, mta_tax, tip_amount, tolls_amount,
    improvement_surcharge, total_amount
)
FROM (
    SELECT
        $1:vendorID::NUMBER,
        $1:tpepPickupDateTime::TIMESTAMP_NTZ,
        $1:tpepDropoffDateTime::TIMESTAMP_NTZ,
        $1:passengerCount::NUMBER,
        $1:tripDistance::FLOAT,
        $1:rateCodeId::NUMBER,
        $1:storeAndFwdFlag::VARCHAR,
        $1:puLocationId::NUMBER,
        $1:doLocationId::NUMBER,
        $1:paymentType::NUMBER,
        $1:fareAmount::FLOAT,
        $1:extra::FLOAT,
        $1:mtaTax::FLOAT,
        $1:tipAmount::FLOAT,
        $1:tollsAmount::FLOAT,
        $1:improvementSurcharge::FLOAT,
        $1:totalAmount::FLOAT
    FROM @NYC_TAXI_DB.BRONZE.NYC_TLC_STAGE
)
PATTERN = '.*puYear=2019/puMonth=1/.*\.parquet'
FILE_FORMAT = (TYPE = PARQUET)
ON_ERROR = 'CONTINUE';

-- Verify row count
SELECT COUNT(*) AS bronze_row_count FROM NYC_TAXI_DB.BRONZE.RAW_YELLOW_TRIPDATA;
