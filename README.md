# MNIST Digit Recogniser

A full-stack machine learning application that allows users to draw digits and get real-time predictions using a PyTorch model trained on the MNIST dataset.

**Live Demo**: [http://37.27.197.79:8501](http://37.27.197.79:8501)

## Features

- Draw digits and get instant predictions
- View prediction history and provide feedback
- Containerized deployment with Docker
- PostgreSQL database for analytics

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
├── database/                    # Database configuration
│   └── init.sql                # Database initialization script
│
├── model/                      # Machine learning model
│   ├── model.py              # Model architecture
│   ├── train.py              # Training script
│   ├── dockerfile_model      # Model training container
│   └── requirements_model.txt # Model dependencies
│
├── webapp/                     # Web application
│   ├── webapp.py             # Streamlit application
│   ├── dockerfile_webapp     # Web app container
│   └── requirements_webapp.txt # Web app dependencies
│
├── docker-compose.yml         # Docker services config
├── deploy.sh                  # Local deployment script
├── deploy_remotely.sh         # Remote deployment script
├── .env.template              # Environment template
├── .gitignore                # Git ignore rules
└── README.md                 # Project documentation
```