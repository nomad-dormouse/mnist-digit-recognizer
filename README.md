# MNIST Digit Recogniser

A full-stack machine learning application that allows users to draw digits and get real-time predictions using a PyTorch model trained on the MNIST dataset.

**Live Demo**: [http://37.27.197.79:8501](http://37.27.197.79:8501)

## Features

- Draw digits and get instant predictions
- Containerized microservices architecture with Docker
- PostgreSQL database for analytics


## Architecture

The application consists of four main services:

1. **Model Training Service** (`model/`)
   - Trains the CNN model on MNIST dataset
   - Handles data preprocessing and normalization
   - Saves trained model weights and architecture

2. **Web Server Service** (`webserver/`)
   - FastAPI backend for model inference
   - Handles image processing and predictions
   - Manages database interactions
   - Provides RESTful API endpoints

3. **Web Application Service** (`webapp/`)
   - Streamlit-based user interface
   - Drawing canvas for digit input
   - Real-time prediction display
   - Prediction history visualization

4. **Database Service** (`database/`)
   - PostgreSQL database
   - Stores prediction history
   - Enables analytics and feedback collection

## Quick Start

### Local Deployment

1. Clone the repository:
   ```bash
   git clone https://github.com/nomad-dormouse/mnist-digit-recogniser
   cd mnist-digit-recogniser
   ```

2. Set up environment variables:
   ```bash
   cp .env.template .env
   ```
   Then edit `.env` file to update configuration specific to your environment

3. Deploy locally:
   ```bash
   ./deploy.sh
   ```

4. Access at `http://localhost:8501`

### Remote Deployment

1. Deploy to remote server:
   ```bash
   ./deploy_remotely.sh
   ```

2. Access at `http://your-server-ip:8501`

## Project Structure

```
mnist-digit-recogniser/
│
├── database/                   # Database service
│   └── init.sql              # Database initialization
│
├── model/                      # Model training service
│   ├── model.py               # CNN model architecture
│   ├── train.py               # Training script
│   ├── dataset/               # MNIST dataset directory
│   │   └── MNIST/            # Downloaded dataset
│   ├── trained_model/         # Saved model files
│   ├── dockerfile_model       # Model container config
│   └── requirements_model.txt # Model dependencies
│
├── webserver/                  # FastAPI backend service
│   ├── webserver.py          # API endpoints and inference
│   ├── dockerfile_webserver   # Server container config
│   └── requirements_webserver.txt # Server dependencies
│
├── webapp/                     # Streamlit frontend service
│   ├── webapp.py             # User interface
│   ├── dockerfile_webapp      # Frontend container config
│   └── requirements_webapp.txt # Frontend dependencies
│
├── docker-compose.yml         # Services orchestration
├── .env.template              # Environment template
├── .gitignore                # Git ignore rules
└── README.md                 # Documentation
```
