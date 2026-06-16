"""
NYC Taxi Platform: Streamlit Dashboard
Displays Gold-layer metrics and ML prediction results.
"""

import streamlit as st
from snowflake.snowpark import Session
import pandas as pd
import os


@st.cache_resource
def get_session() -> Session:
    """Create a cached Snowpark session from environment variables."""
    return Session.builder.configs({
        "account": os.environ["SNOWFLAKE_ACCOUNT"],
        "user": os.environ["SNOWFLAKE_USER"],
        "password": os.environ["SNOWFLAKE_PASSWORD"],
        "role": "SYSADMIN",
        "warehouse": "NYC_TAXI_WH",
        "database": "NYC_TAXI_DB",
        "schema": "GOLD",
    }).create()


def load_table(session: Session, table_name: str) -> pd.DataFrame:
    return session.table(table_name).to_pandas()


def main():
    st.set_page_config(page_title="NYC Taxi Platform", layout="wide")
    st.title("NYC Taxi Platform Dashboard")
    st.markdown("Medallion Architecture: Bronze -> Silver -> Gold -> ML Predictions")

    session = get_session()

    # --- Tabs ---
    tab1, tab2, tab3, tab4 = st.tabs([
        "Hourly Metrics", "Daily Metrics", "Payment Breakdown", "ML Predictions"
    ])

    # --- Tab 1: Hourly Metrics ---
    with tab1:
        st.subheader("Trip Metrics by Hour of Day")
        df_hourly = load_table(session, "NYC_TAXI_DB.GOLD.HOURLY_TRIP_METRICS")

        col1, col2, col3 = st.columns(3)
        col1.metric("Total Trips", f"{df_hourly['TOTAL_TRIPS'].sum():,.0f}")
        col2.metric("Avg Fare", f"${df_hourly['AVG_FARE'].mean():.2f}")
        col3.metric("Total Revenue", f"${df_hourly['TOTAL_REVENUE'].sum():,.0f}")

        st.line_chart(df_hourly.set_index("PICKUP_HOUR")[["TOTAL_TRIPS"]])
        st.bar_chart(df_hourly.set_index("PICKUP_HOUR")[["AVG_FARE", "AVG_TIP"]])

    # --- Tab 2: Daily Metrics ---
    with tab2:
        st.subheader("Trip Metrics by Day of Week")
        df_daily = load_table(session, "NYC_TAXI_DB.GOLD.DAILY_TRIP_METRICS")
        st.dataframe(df_daily, use_container_width=True)
        st.bar_chart(df_daily.set_index("DAY_NAME")[["TOTAL_TRIPS", "AVG_FARE"]])

    # --- Tab 3: Payment Type Breakdown ---
    with tab3:
        st.subheader("Payment Type Distribution")
        df_payment = load_table(session, "NYC_TAXI_DB.GOLD.PAYMENT_TYPE_METRICS")
        st.dataframe(df_payment, use_container_width=True)
        st.bar_chart(df_payment.set_index("PAYMENT_TYPE_NAME")[["TOTAL_TRIPS"]])

    # --- Tab 4: ML Predictions ---
    with tab4:
        st.subheader("Fare Prediction Model Results")

        # Model metrics
        df_metrics = load_table(session, "NYC_TAXI_DB.GOLD.MODEL_METRICS")
        if not df_metrics.empty:
            m = df_metrics.iloc[0]
            col1, col2, col3 = st.columns(3)
            col1.metric("Model", m["MODEL_NAME"])
            col2.metric("MAE", f"${m['MAE']:.2f}")
            col3.metric("R² Score", f"{m['R2_SCORE']:.4f}")

        # Predictions sample
        df_preds = load_table(session, "NYC_TAXI_DB.GOLD.TAXI_PREDICTIONS")
        st.write(f"Total predictions: {len(df_preds):,}")

        st.scatter_chart(
            df_preds.head(5000),
            x="ACTUAL_FARE",
            y="PREDICTED_FARE",
        )

        with st.expander("View Prediction Data Sample"):
            st.dataframe(df_preds.head(100), use_container_width=True)


if __name__ == "__main__":
    main()
