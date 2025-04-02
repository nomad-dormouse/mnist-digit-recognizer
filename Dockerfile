# Multi-stage Dockerfile for MNIST Digit Recognizer
# This Dockerfile provides both local development and production builds

# Base stage with common dependencies
FROM python:3.9-slim AS base

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

# -----------------------------------------------------------------------------
# Local development stage
FROM base AS local

# Copy the application code
COPY . .

# Patch the app.py file to use the database service name for connectivity
# and to skip the 'db' hostname attempt in local Docker
RUN sed -i 's/DB_HOST = os.getenv.*$/DB_HOST = "db"/' app.py && \
    sed -i 's/is_running_locally = not os.environ.get.*/is_running_locally = False/' app.py && \
    sed -i 's/if os.path.exists.*or os.environ.get.*/if False:/' app.py

# Set local-specific environment variables
ENV DB_HOST=db \
    DB_PORT=5432 \
    DB_NAME=mnist_db \
    DB_USER=postgres \
    DB_PASSWORD=postgres

# Command to run the application with development settings
CMD ["streamlit", "run", "app.py", "--server.address", "0.0.0.0"]

# -----------------------------------------------------------------------------
# Production stage
FROM base AS remote

# Copy the application code
COPY . .

# Set production-specific environment variables
ENV STREAMLIT_SERVER_ENABLE_CORS=false

# Command to run the application with production settings
CMD ["streamlit", "run", "app.py", "--server.address", "0.0.0.0"] 