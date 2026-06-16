-- ============================================================
-- NYC Taxi Platform: Infrastructure Setup
-- Creates database, schemas (Medallion layers), and warehouse
-- ============================================================

USE ROLE SYSADMIN;

-- Create the database
CREATE DATABASE IF NOT EXISTS NYC_TAXI_DB;

-- Create Medallion architecture schemas
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.BRONZE;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.SILVER;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.GOLD;

-- Create a dedicated warehouse
CREATE WAREHOUSE IF NOT EXISTS NYC_TAXI_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- Grant usage
GRANT USAGE ON DATABASE NYC_TAXI_DB TO ROLE SYSADMIN;
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE SYSADMIN;

-- Set context for subsequent scripts
USE DATABASE NYC_TAXI_DB;
USE WAREHOUSE NYC_TAXI_WH;
