# Base Dockerfile for MNIST Digit Recognizer
# This file contains common configuration shared by all environments

FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create directory for model
RUN mkdir -p model/saved_models

# Set common environment variables
ENV PYTHONUNBUFFERED=1 \
    STREAMLIT_SERVER_PORT=8501 \
    STREAMLIT_SERVER_HEADLESS=true

# Expose the port Streamlit will run on
EXPOSE 8501

# The CMD instruction will be provided by specific environment Dockerfiles 