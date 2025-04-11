# MNIST DIGIT RECOGNISER DOCKERFILE

# Base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy project code
COPY . .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt && \
    rm -rf /root/.cache/pip

# Run the Streamlit app
CMD ["streamlit", "run", "app.py", "--server.address=0.0.0.0"]