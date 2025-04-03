# MNIST DIGIT RECOGNIZER DOCKERFILE
#
# Image for both local and remote environments

FROM python:3.9-slim

WORKDIR /

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

# Copy the application code
COPY . .

# Set Python to run unbuffered
ENV PYTHONUNBUFFERED=1 \
    STREAMLIT_SERVER_HEADLESS=true \
    STREAMLIT_BROWSER_GATHER_USAGE_STATS=false

# Expose the port Streamlit will run on
EXPOSE 8501

# Command to run the application
CMD ["streamlit", "run", "app.py", "--server.address", "0.0.0.0"] 