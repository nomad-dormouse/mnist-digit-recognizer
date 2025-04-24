# MNIST Digit Recogniser

A full-stack machine learning application that allows users to draw digits and get real-time predictions using a PyTorch model trained on the MNIST dataset.

**Live Demo**: [http://37.27.197.79:8501](http://37.27.197.79:8501)

**GitHub Repository**: [https://github.com/nomad-dormouse/mnist-digit-recogniser](https://github.com/nomad-dormouse/mnist-digit-recogniser)

## Features

- Deep learning model for handwritten digit classification (PyTorch)
- Interactive web interface with drawing canvas (Streamlit)
- Database for prediction logging and analytics (PostgreSQL)
- Containerized deployment with Docker and Docker Compose
- Automated model training and verification
- Prediction history tracking with user feedback

## Project Overview

This project demonstrates an end-to-end machine learning application that:

1. Implements a PyTorch Convolutional Neural Network (CNN) trained on the MNIST dataset
2. Provides an intuitive web interface for drawing digits and receiving real-time predictions
3. Records predictions and user feedback in a PostgreSQL database for continuous improvement
4. Deploys seamlessly using containerization for consistent environments

## Project Structure

```
project_root/
├── database/                # Database related files
│   └── init.sql            # Database initialization script
├── model/                   # Model training and inference
│   ├── model.py            # Model architecture definition
│   ├── train.py            # Model training script
│   ├── dockerfile_model    # Dockerfile for model training
│   └── requirements_model.txt  # Python dependencies for model
├── webapp/                  # Web application
│   ├── webapp.py           # Streamlit web application
│   ├── dockerfile_webapp   # Dockerfile for web application
│   └── requirements_webapp.txt # Python dependencies for webapp
├── docker-compose.yml      # Docker services configuration
├── deploy.sh               # Deployment script
├── .env.template           # Template for environment variables
└── .env                    # Environment variables (create from template)
```

## Quick Start

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd mnist-digit-recogniser
   ```

2. Create `.env` file from template:
   ```bash
   cp .env.template .env
   ```

3. Run the deployment script:
   ```bash
   ./deploy.sh
   ```

4. Access the application at `http://localhost:8501`

## Components

### Model Training
- Implements CNN using PyTorch
- Handles model training and validation
- Supports loading existing models

### Web Application
- Drawing canvas for digit input
- Real-time predictions with confidence scores
- Prediction history display
- User feedback collection

### Database
- PostgreSQL database for prediction logging
- Stores predictions, timestamps, and user feedback

## Development

### Model Training
To manually trigger training:
```bash
docker-compose run --rm --build mnist_model_service
```

### Logs
To view service logs:
```bash
docker-compose logs [service_name]
```

## License

[MIT License](LICENSE) 
