"""
Sample Streamlit app for the EC2 Streamlit Deployment Playbook.
Demonstrates loading .env variables and basic Streamlit UI.
"""

import os
import streamlit as st
from dotenv import load_dotenv

load_dotenv()

st.set_page_config(
    page_title="EC2 Streamlit App",
    page_icon="🚀",
    layout="wide",
)

st.title("EC2 Streamlit Deployment Demo")
st.write("If you can see this page, your Streamlit app is deployed and running correctly.")

st.divider()

col1, col2 = st.columns(2)

with col1:
    st.subheader("Environment Status")
    app_env = os.getenv("APP_ENV", "development")
    if app_env == "production":
        st.success(f"Environment: **{app_env}**")
    else:
        st.warning(f"Environment: **{app_env}**")

    st.subheader("Health Check")
    st.success("Streamlit is running.")
    st.info("Nginx reverse proxy: connected.")

with col2:
    st.subheader("Configuration (Non-Sensitive)")
    st.write("These are safe to display — no secrets shown here.")

    port = os.getenv("STREAMLIT_SERVER_PORT", "8501")
    st.code(f"Server port: {port}")

    openai_key = os.getenv("OPENAI_API_KEY", "")
    if openai_key:
        st.success("OPENAI_API_KEY: configured (hidden)")
    else:
        st.warning("OPENAI_API_KEY: not set")

st.divider()

st.subheader("Sample Data Table")
import pandas as pd
import numpy as np

df = pd.DataFrame(
    np.random.randn(10, 3),
    columns=["Column A", "Column B", "Column C"]
)
st.dataframe(df, use_container_width=True)

st.subheader("Sample Chart")
chart_data = pd.DataFrame(
    np.random.randn(20, 3),
    columns=["Metric 1", "Metric 2", "Metric 3"]
)
st.line_chart(chart_data)

st.divider()
st.caption("EC2 Streamlit Deployment Playbook — Sample App")
